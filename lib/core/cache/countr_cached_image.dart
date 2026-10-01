import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Managed, offline-first cached image widget replacing unmanaged [Image.network].
/// Backed by [CountrImageCacheManager] for 35+ day local disk persistence.
class CountrCachedImage extends StatelessWidget {
  final String imageUrl;
  final String? cacheKey;
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

  const CountrCachedImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
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
    this.fadeInDuration = const Duration(milliseconds: 150),
    this.alignment = Alignment.center,
  });

  /// Canonical Scryfall named redirect endpoint URL builder for MTG cards.
  static String buildScryfallNamedUrl(String name, {String version = 'art_crop'}) {
    final clean = name.contains('//') ? name.split('//').first.trim() : name.trim();
    return 'https://api.scryfall.com/cards/named?exact=${Uri.encodeComponent(clean)}&format=image&version=$version';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Support local file system images (file:// or absolute / path)
    if (_isLocalFile(imageUrl)) {
      final filePath = imageUrl.startsWith('file://')
          ? Uri.decodeFull(imageUrl.substring(7))
          : imageUrl;
      final fileWidget = Image.file(
        File(filePath),
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) =>
            _buildEffectiveErrorWidget(context),
      );
      if (borderRadius != null) {
        return ClipRRect(
          borderRadius: borderRadius!,
          child: fileWidget,
        );
      }
      return fileWidget;
    }

    // 2. Resolve candidate fallback URL for MTG or specified fallback
    final candidateFallback = _resolveCandidateFallback();

    // 3. Detect invalid or empty initial image URL
    final isInvalidInitialUrl = imageUrl.trim().isEmpty ||
        imageUrl.contains('/art_crop/back.jpg') ||
        imageUrl.contains('/normal/back.jpg') ||
        imageUrl.contains('/small/back.jpg');

    final effectiveUrl = isInvalidInitialUrl && candidateFallback != null
        ? candidateFallback
        : imageUrl.trim();

    if (effectiveUrl.isEmpty) {
      return _buildEffectiveErrorWidget(context);
    }

    // 4. Test environment headless rendering
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      final testWidget = Image(
        image: NetworkImage(effectiveUrl),
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _buildDefaultLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          if (candidateFallback != null &&
              candidateFallback.isNotEmpty &&
              candidateFallback != effectiveUrl) {
            return Image(
              image: NetworkImage(candidateFallback),
              fit: fit,
              width: width,
              height: height,
              alignment: alignment,
              errorBuilder: (ctx, err, stack) =>
                  _buildEffectiveErrorWidget(context),
            );
          }
          return _buildEffectiveErrorWidget(context);
        },
      );
      if (borderRadius != null) {
        return ClipRRect(
          borderRadius: borderRadius!,
          child: testWidget,
        );
      }
      return testWidget;
    }

    // 5. Production cached network image backed by CountrImageCacheManager
    final cachedImage = CachedNetworkImage(
      imageUrl: effectiveUrl,
      cacheKey: cacheKey,
      cacheManager: cacheManager ?? CountrImageCacheManager(),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      fadeInDuration: fadeInDuration,
      placeholder: (context, url) =>
          placeholder ?? _buildDefaultLoadingPlaceholder(),
      errorWidget: (context, url, error) {
        if (candidateFallback != null &&
            candidateFallback.isNotEmpty &&
            candidateFallback != effectiveUrl) {
          return CachedNetworkImage(
            imageUrl: candidateFallback,
            cacheKey: cacheKey != null ? '${cacheKey}_fallback' : null,
            cacheManager: cacheManager ?? CountrImageCacheManager(),
            fit: fit,
            width: width,
            height: height,
            alignment: alignment,
            fadeInDuration: fadeInDuration,
            placeholder: (ctx, u) =>
                placeholder ?? _buildDefaultLoadingPlaceholder(),
            errorWidget: (ctx, u, err) => _buildEffectiveErrorWidget(context),
          );
        }
        return _buildEffectiveErrorWidget(context);
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: cachedImage,
      );
    }

    return cachedImage;
  }

  bool _isLocalFile(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith('file://') ||
        (trimmed.startsWith('/') && !trimmed.startsWith('//'));
  }

  String? _resolveCandidateFallback() {
    if (fallbackUrl != null && fallbackUrl!.trim().isNotEmpty) {
      return fallbackUrl!.trim();
    }
    final name = cardName?.trim() ?? '';
    final domain = (tcgDomain ?? 'mtg').trim().toLowerCase();
    if (domain == 'mtg' && name.isNotEmpty && name != 'Unknown Card') {
      return buildScryfallNamedUrl(name);
    }
    return null;
  }

  Widget _buildDefaultLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
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
    if (errorWidget != null) {
      // Intercept Icons.image_not_supported or broken image icons and replace with styled placeholder
      if (errorWidget is Icon) {
        final icon = (errorWidget as Icon).icon;
        if (icon == Icons.image_not_supported ||
            icon == Icons.image_not_supported_outlined ||
            icon == Icons.broken_image ||
            icon == Icons.broken_image_outlined) {
          return _buildCardPlaceholder(context);
        }
      }
      return errorWidget!;
    }
    return _buildCardPlaceholder(context);
  }

  /// Elegant styled card placeholder with subtle dark gradient and card initials / name.
  Widget _buildCardPlaceholder(BuildContext context) {
    final name = cardName?.trim() ?? '';
    final initials = _getInitials(name);
    final isSmall = (width != null && width! < 60) || (height != null && height! < 70);

    final placeholderContent = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
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
                  if (!isSmall && name.isNotEmpty && (height == null || height! >= 90)) ...[
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

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
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
}


import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Managed, offline-first cached image widget replacing unmanaged [Image.network].
/// Backed by [CountrImageCacheManager] for 35+ day local disk persistence.
class CountrCachedImage extends StatelessWidget {
  final String imageUrl;
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
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 150),
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return _buildFallback(context);
    }

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      final testWidget = Image(
        image: NetworkImage(imageUrl),
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: AppColors.surfaceRaised,
                child: const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? _buildFallback(context),
      );
      if (borderRadius != null) {
        return ClipRRect(
          borderRadius: borderRadius!,
          child: testWidget,
        );
      }
      return testWidget;
    }

    final cachedImage = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: CountrImageCacheManager(),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      fadeInDuration: fadeInDuration,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: AppColors.surfaceRaised,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentCyan,
                ),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildFallback(context),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: cachedImage,
      );
    }

    return cachedImage;
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceRaised,
      child: const Center(
        child: Icon(
          Icons.style_rounded,
          size: 24,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

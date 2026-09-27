// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:countr/core/cache/countr_cached_image.dart';

/// Dynamic Commander art backdrop widget (Feature 30).
///
/// Renders an MTG commander's `art_crop` (or custom art override) with calibrated
/// 0.25–0.35 opacity and a dark multi-stop vignette gradient ensuring WCAG AAA contrast
/// for foreground life totals and secondary trackers.
///
/// Features:
/// - Dynamic art loading via [CountrCachedImage] with maximum offline retention (30+ days).
/// - Default opacity of 0.30 (configurable between 0.20 and 0.45).
/// - Multi-stop vertical and subtle radial vignette overlays to prevent low-contrast text collisions.
/// - Graceful offline & empty fallback rendering a clean, rich dark gradient (no broken image icons or crashes).
/// - Completely gesture-transparent ([IgnorePointer]) so background rendering never blocks touch hitboxes.
class CommanderArtBackdrop extends StatelessWidget {
  /// The image URL to render (e.g. Scryfall `art_crop` URL or local file path).
  final String? imageUrl;

  /// Opacity applied to the image layer (defaults to 0.30, clamped between 0.0 and 1.0).
  final double opacity;

  /// Colors for the vertical vignette gradient (defaults to dark shading at edges and lighter center).
  final List<Color>? vignetteColors;

  /// Stops for the vertical vignette gradient (defaults to 0.0, 0.45, 1.0).
  final List<double>? vignetteStops;

  /// Custom fallback gradient displayed when [imageUrl] is null, empty, or fails to load.
  final Gradient? fallbackGradient;

  /// The BoxFit mode for image scaling (defaults to [BoxFit.cover]).
  final BoxFit fit;

  /// Optional child widget placed on top of the backdrop.
  final Widget? child;

  /// Alignment for image positioning within the quadrant.
  final Alignment alignment;

  const CommanderArtBackdrop({
    super.key,
    this.imageUrl,
    this.opacity = 0.30,
    this.vignetteColors,
    this.vignetteStops,
    this.fallbackGradient,
    this.fit = BoxFit.cover,
    this.child,
    this.alignment = Alignment.center,
  });

  /// Default clean dark theme gradient for offline/empty states.
  static const Gradient defaultFallbackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E1E2C),
      Color(0xFF141420),
      Color(0xFF0F0F18),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final effectiveOpacity = opacity.clamp(0.0, 1.0);
    final hasValidUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base dark background layer (guarantees solid backdrop)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: fallbackGradient ?? defaultFallbackGradient,
            ),
          ),

          // 2. Commander Art Crop Image Layer with Opacity
          if (hasValidUrl)
            Opacity(
              opacity: effectiveOpacity,
              child: CountrCachedImage(
                imageUrl: imageUrl!.trim(),
                fit: fit,
                alignment: alignment,
                width: double.infinity,
                height: double.infinity,
                errorWidget: const SizedBox.shrink(),
              ),
            ),

          // 3. Dark Multi-Stop Vertical Vignette Layer (WCAG AAA Contrast)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: vignetteColors ??
                    [
                      Colors.black.withValues(alpha: 0.50), // Header protection
                      Colors.black.withValues(alpha: 0.20), // Center numbers clarity
                      Colors.black.withValues(alpha: 0.70), // Bottom drawers & controls
                    ],
                stops: vignetteStops ?? const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // 4. Subtle Radial Corner Vignette Layer
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.65, 1.0],
              ),
            ),
          ),

          // 5. Optional Child Layer
          ?child,
        ],
      ),
    );
  }
}

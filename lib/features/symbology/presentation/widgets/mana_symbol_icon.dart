// Copyright (c) 2026 Countr. All rights reserved.
// MTG Mana Symbol Icon Widget.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';

/// Renders a single official MTG card symbol as a crisp, circular vector icon.
///
/// Features:
/// - Explicit square dimensions ([size] x [size]) preventing layout shifts.
/// - Circular boundary clipping mirroring official card printing.
/// - Accessible screen reader descriptions via [Semantics].
/// - Graceful fallback to styled text badge if asset is missing or fails to render.
/// - Optional surrounding [padding].
class ManaSymbolIcon extends StatelessWidget {
  /// The symbol code (e.g. `"{W}"`, `"W"`, `"{W/U}"`, `"P/B"`, `"{2}"`).
  final String symbolCode;

  /// The width and height of the icon in logical pixels. Defaults to 16.0.
  final double size;

  final String? _assetPath;

  /// Flutter asset path for this symbol.
  /// If not explicitly provided, resolved dynamically from [symbolCode] via [ScryfallSymbolCatalog].
  String? get assetPath => _assetPath ?? ScryfallSymbolCatalog.resolveAssetPath(symbolCode);

  /// Optional padding around the icon.
  final EdgeInsetsGeometry? padding;

  /// Accessibility description read by assistive technologies.
  /// If null, resolved from [ScryfallSymbol.english] (e.g. "one white or blue mana").
  final String? semanticLabel;

  /// Whether to clip the SVG strictly to an oval/circle. Defaults to true.
  final bool circular;

  /// Custom builder for fallback rendering if the asset cannot be resolved or loaded.
  final Widget Function(BuildContext context, String symbolCode, double size)? fallbackBuilder;

  const ManaSymbolIcon({
    super.key,
    required this.symbolCode,
    this.size = 16.0,
    String? assetPath,
    this.padding,
    this.semanticLabel,
    this.circular = true,
    this.fallbackBuilder,
  }) : _assetPath = assetPath;

  @override
  Widget build(BuildContext context) {
    final effectiveAssetPath = assetPath;
    final symbolModel = ScryfallSymbolCatalog.findBySymbol(symbolCode);
    final effectiveSemanticLabel = semanticLabel ??
        symbolModel?.english ??
        'Mana symbol $symbolCode';

    Widget content;
    if (effectiveAssetPath != null && effectiveAssetPath.isNotEmpty) {
      content = SvgPicture.asset(
        effectiveAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        excludeFromSemantics: true,
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
        errorBuilder: (context, error, stackTrace) {
          return fallbackBuilder?.call(context, symbolCode, size) ??
              _buildDefaultFallback(context);
        },
      );
    } else {
      content = fallbackBuilder?.call(context, symbolCode, size) ??
          _buildDefaultFallback(context);
    }

    if (circular) {
      content = ClipOval(child: content);
    }

    content = SizedBox(
      width: size,
      height: size,
      child: content,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Semantics(
      label: effectiveSemanticLabel,
      image: true,
      child: content,
    );
  }

  Widget _buildDefaultFallback(BuildContext context) {
    final clean = symbolCode.replaceAll('{', '').replaceAll('}', '').trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceRaised,
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 0.8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: Text(
            clean.isNotEmpty ? clean : '?',
            style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

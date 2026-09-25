// Copyright (c) 2026 Countr. All rights reserved.
// MTG Mana Cost Bar Presentation Widget.

import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

/// A dedicated presentation widget for contiguous MTG mana costs (e.g. `"{2}{U}{B}"`).
///
/// Features:
/// - Extracts and resolves individual mana symbols via [ScryfallSymbolCatalog].
/// - Displays symbols horizontally with consistent [spacing].
/// - Automatic [FittedBox] scale-down mode preventing horizontal `RenderFlex`
///   overflows in constrained viewports (e.g. 80px column in DeckBuilderScreen).
/// - Fallback rendering for non-symbol or malformed mana strings.
/// - Screen reader accessibility announcing full spoken mana costs.
class ManaCostBar extends StatelessWidget {
  /// The contiguous mana cost string (e.g. `"{2}{U}{B}"`, `"{1}{G}{W}"`, `"{P/B}"`).
  final String manaCost;

  /// The size (width and height) of each symbol icon. Defaults to 13.0.
  final double symbolSize;

  /// The horizontal spacing between adjacent symbols. Defaults to 2.0.
  final double spacing;

  /// Whether to wrap the row in a [FittedBox] with [BoxFit.scaleDown]
  /// to prevent RenderFlex overflow when width is constrained. Defaults to true.
  final bool enableFittedBox;

  /// Alignment used by [FittedBox] and the internal [Row].
  /// Defaults to [Alignment.centerLeft].
  final AlignmentGeometry alignment;

  /// Main axis size for the internal [Row]. Defaults to [MainAxisSize.min].
  final MainAxisSize mainAxisSize;

  /// Optional fallback text style if [manaCost] contains no recognized symbols.
  final TextStyle? fallbackTextStyle;

  /// Optional override for screen reader description.
  final String? semanticLabel;

  const ManaCostBar({
    super.key,
    required this.manaCost,
    this.symbolSize = 13.0,
    this.spacing = 2.0,
    this.enableFittedBox = true,
    this.alignment = Alignment.centerLeft,
    this.mainAxisSize = MainAxisSize.min,
    this.fallbackTextStyle,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = manaCost.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    final symbols = ScryfallSymbolCatalog.extractSymbols(trimmed);
    if (symbols.isEmpty) {
      return Text(
        trimmed,
        style: fallbackTextStyle ??
            TextStyle(
              fontSize: symbolSize,
              fontWeight: FontWeight.w600,
              color: AppColors.accentCyan,
            ),
      );
    }

    Widget content = Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: _alignmentToMainAxisAlignment(alignment),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < symbols.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          ManaSymbolIcon(
            symbolCode: symbols[i],
            assetPath: ScryfallSymbolCatalog.resolveAssetPath(symbols[i]),
            size: symbolSize,
          ),
        ],
      ],
    );

    if (enableFittedBox) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: content,
      );
    }

    final effectiveLabel = semanticLabel ?? _generateSemanticLabel(symbols);

    return Semantics(
      label: effectiveLabel,
      child: content,
    );
  }

  static MainAxisAlignment _alignmentToMainAxisAlignment(AlignmentGeometry alignment) {
    if (alignment == Alignment.centerRight ||
        alignment == Alignment.topRight ||
        alignment == Alignment.bottomRight) {
      return MainAxisAlignment.end;
    }
    if (alignment == Alignment.center) {
      return MainAxisAlignment.center;
    }
    return MainAxisAlignment.start;
  }

  static String _generateSemanticLabel(List<String> symbols) {
    final descriptions = symbols.map((s) {
      final model = ScryfallSymbolCatalog.findBySymbol(s);
      return model?.english ?? s;
    }).join(', ');
    return 'Mana cost: $descriptions';
  }
}

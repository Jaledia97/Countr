// Copyright (c) 2026 Countr. All rights reserved.
// MTG Mana Text Parser Domain Engine.

import 'package:flutter/widgets.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

/// Core parsing engine that tokenizes arbitrary text containing Magic: The Gathering
/// bracketed symbol codes (e.g. `{1}{W}{U}`, `{T}`, `{½}`, `{B/G/P}`) into Flutter
/// [InlineSpan] hierarchies, rendering vector mana icons as [WidgetSpan]s while
/// preserving plain text and malformed input as [TextSpan]s.
abstract final class ManaTextParser {
  /// Regular expression matching standard MTG bracketed symbol expressions.
  /// Matches strings like `{W}`, `{2/U}`, `{B/G/P}`, `{½}`, `{∞}`, `{T}`, etc.
  static final RegExp symbolRegex = RegExp(r'\{([A-Za-z0-9/½∞?]+)\}');

  /// Parses [text] into a list of [InlineSpan]s where recognized MTG symbols
  /// are replaced by [WidgetSpan]s with [PlaceholderAlignment.middle], while
  /// plain text, unclosed brackets, unknown symbols, and empty/nested braces
  /// are preserved safely as [TextSpan]s without throwing exceptions.
  ///
  /// Parameters:
  /// - [text]: The raw input string to parse.
  /// - [baseStyle]: The typography style applied to surrounding text runs.
  /// - [symbolSize]: Explicit icon diameter. If null, calculated from [baseStyle.fontSize] * [scaleFactor].
  /// - [scaleFactor]: Multiplier for font size when calculating icon dimensions (default: 1.1).
  /// - [symbolPadding]: Subtle padding surrounding each symbol (default: 1.5px horizontal).
  /// - [symbolBuilder]: Optional builder callback for custom icon widgets or test mocking.
  static List<InlineSpan> parse({
    required String text,
    required TextStyle baseStyle,
    double? symbolSize,
    double scaleFactor = 1.1,
    EdgeInsetsGeometry symbolPadding = const EdgeInsets.symmetric(horizontal: 1.5),
    Widget Function(String symbolCode, String assetPath, double size)? symbolBuilder,
  }) {
    if (text.isEmpty) {
      return const <InlineSpan>[];
    }

    final effectiveSize = symbolSize ?? ((baseStyle.fontSize ?? 14.0) * scaleFactor);
    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in symbolRegex.allMatches(text)) {
      final rawToken = match.group(1)!;
      final assetPath = ScryfallSymbolCatalog.resolveAssetPath(rawToken);

      // If unrecognized symbol (e.g. {NotASymbol}, {Reminder}), skip so it passes through as text.
      if (assetPath == null) {
        continue;
      }

      // 1. Append any preceding text between last match end and current match start
      if (match.start > lastMatchEnd) {
        final precedingText = text.substring(lastMatchEnd, match.start);
        _addTextSpan(spans, precedingText, baseStyle);
      }

      // 2. Build WidgetSpan for the recognized symbol
      final Widget iconWidget = symbolBuilder != null
          ? symbolBuilder(rawToken, assetPath, effectiveSize)
          : ManaSymbolIcon(
              symbolCode: rawToken,
              assetPath: assetPath,
              size: effectiveSize,
            );

      final Widget child = symbolPadding != EdgeInsets.zero
          ? Padding(
              padding: symbolPadding,
              child: iconWidget,
            )
          : iconWidget;

      spans.add(ManaSymbolSpan(
        alignment: PlaceholderAlignment.middle,
        child: child,
        rawSymbol: rawToken,
      ));

      lastMatchEnd = match.end;
    }

    // 3. Append any remaining trailing text after the last match
    if (lastMatchEnd < text.length) {
      final trailingText = text.substring(lastMatchEnd);
      _addTextSpan(spans, trailingText, baseStyle);
    }

    return spans;
  }

  /// Appends text to [spans], coalescing with the previous [TextSpan]
  /// if it shares the identical [TextStyle] to prevent span fragmentation.
  static void _addTextSpan(List<InlineSpan> spans, String text, TextStyle style) {
    if (text.isEmpty) return;
    if (spans.isNotEmpty && spans.last is TextSpan) {
      final last = spans.last as TextSpan;
      if (last.style == style && (last.children == null || last.children!.isEmpty)) {
        spans[spans.length - 1] = TextSpan(
          text: '${last.text ?? ""}$text',
          style: style,
        );
        return;
      }
    }
    spans.add(TextSpan(text: text, style: style));
  }
}

/// A specialized [WidgetSpan] that represents an MTG mana/game symbol.
///
/// Overrides [computeToPlainText] so that accessibility tools, clipboard
/// copies, and test finders encounter the canonical bracketed symbol token
/// (e.g. `{$rawSymbol}`) rather than the standard Unicode object replacement
/// character (`\uFFFC`).
class ManaSymbolSpan extends WidgetSpan {
  /// The raw symbol code, e.g. "T", "W", "2/U".
  final String rawSymbol;

  const ManaSymbolSpan({
    required super.child,
    required this.rawSymbol,
    super.alignment = PlaceholderAlignment.middle,
    super.baseline,
    super.style,
  });

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {
    if (includePlaceholders) {
      if (rawSymbol.startsWith('{') && rawSymbol.endsWith('}')) {
        buffer.write(rawSymbol);
      } else {
        buffer.write('{$rawSymbol}');
      }
    }
  }
}

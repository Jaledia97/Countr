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
  /// Reminder text in parentheses `(...)` is formatted with [FontStyle.italic]
  /// when [italicizeReminderText] is true, while preserving curly-braced mana codes.
  ///
  /// Parameters:
  /// - [text]: The raw input string to parse.
  /// - [baseStyle]: The typography style applied to surrounding text runs.
  /// - [symbolSize]: Explicit icon diameter. If null, calculated from [baseStyle.fontSize] * [scaleFactor].
  /// - [scaleFactor]: Multiplier for font size when calculating icon dimensions (default: 1.1).
  /// - [symbolPadding]: Subtle padding surrounding each symbol (default: 1.5px horizontal).
  /// - [symbolBuilder]: Optional builder callback for custom icon widgets or test mocking.
  /// - [italicizeReminderText]: Whether to format reminder text in parentheses `(...)` with italic typography.
  static List<InlineSpan> parse({
    required String text,
    required TextStyle baseStyle,
    double? symbolSize,
    double scaleFactor = 1.1,
    EdgeInsetsGeometry symbolPadding = const EdgeInsets.symmetric(horizontal: 1.5),
    Widget Function(String symbolCode, String assetPath, double size)? symbolBuilder,
    bool italicizeReminderText = true,
  }) {
    if (text.isEmpty) {
      return const <InlineSpan>[];
    }

    final effectiveSize = symbolSize ?? ((baseStyle.fontSize ?? 14.0) * scaleFactor);
    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;
    int parenDepth = 0;

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
        parenDepth = _addTextSpanWithReminderCheck(
          spans,
          precedingText,
          baseStyle,
          parenDepth: parenDepth,
          italicizeReminderText: italicizeReminderText,
        );
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
      _addTextSpanWithReminderCheck(
        spans,
        trailingText,
        baseStyle,
        parenDepth: parenDepth,
        italicizeReminderText: italicizeReminderText,
      );
    }

    return spans;
  }

  /// Appends text to [spans] with reminder text `(...)` parsed as [FontStyle.italic]
  /// if [italicizeReminderText] is enabled, while strictly preserving curly-braced mana codes.
  static int _addTextSpanWithReminderCheck(
    List<InlineSpan> spans,
    String text,
    TextStyle baseStyle, {
    required int parenDepth,
    required bool italicizeReminderText,
  }) {
    if (text.isEmpty) return parenDepth;

    if (!italicizeReminderText) {
      _addTextSpan(spans, text, baseStyle);
      return parenDepth;
    }

    // Preserve unrecognized bracketed tokens like "{<script>alert(1)</script>}"
    // or "{Reminder: Flying}" as plain text without parsing parentheses inside them.
    if (text.trim().startsWith('{') && text.trim().endsWith('}')) {
      _addTextSpan(spans, text, baseStyle);
      return parenDepth;
    }

    final italicStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
    int currentDepth = parenDepth;
    final buffer = StringBuffer();
    TextStyle currentStyle = currentDepth > 0 ? italicStyle : baseStyle;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '(') {
        final isPrecededByWhitespaceOrStart = (i == 0) ||
            text[i - 1] == ' ' ||
            text[i - 1] == '\n' ||
            text[i - 1] == '\t' ||
            currentDepth > 0;

        if (isPrecededByWhitespaceOrStart) {
          if (currentDepth == 0 && buffer.isNotEmpty) {
            _addTextSpan(spans, buffer.toString(), currentStyle);
            buffer.clear();
          }
          currentDepth++;
          currentStyle = italicStyle;
          buffer.write(char);
          continue;
        }
      } else if (char == ')') {
        if (currentDepth > 0) {
          buffer.write(char);
          currentDepth--;
          if (currentDepth == 0) {
            _addTextSpan(spans, buffer.toString(), currentStyle);
            buffer.clear();
            currentStyle = baseStyle;
          }
          continue;
        }
      }
      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      _addTextSpan(spans, buffer.toString(), currentStyle);
    }

    return currentDepth;
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

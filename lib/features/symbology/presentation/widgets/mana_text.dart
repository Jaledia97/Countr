// Copyright (c) 2026 Countr. All rights reserved.
// MTG Mana Text Inline Rich Text Widget.

import 'package:flutter/material.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';

/// A drop-in replacement for [Text] that renders mixed natural language text
/// interspersed with bracketed MTG symbols (e.g. `"{T}: Add {G}."`, `"{2}{W}{U}"`)
/// as inline vector graphics without disrupting typography flow.
///
/// Features:
/// - Full inheritance and merging with [DefaultTextStyle.of(context)].
/// - Proportional symbol scaling based on [TextStyle.fontSize] (default 1.1x).
/// - Middle vertical alignment ([PlaceholderAlignment.middle]) keeping icons
///   optically aligned with cap-height and x-height.
/// - Unclosed braces and unrecognized bracketed tokens pass through safely as plain text.
/// - Adheres to [textAlign], [maxLines], [overflow], and [softWrap].
class ManaText extends StatelessWidget {
  /// The raw string containing plain text and bracketed MTG symbol codes.
  final String text;

  /// The text style to apply. Merged with [DefaultTextStyle.of(context)].
  final TextStyle? style;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The directionality of the text.
  final TextDirection? textDirection;

  /// Whether the text should break at soft line breaks.
  final bool? softWrap;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// An optional maximum number of lines for the text to span.
  final int? maxLines;

  /// Scale factor for symbol icon size relative to [TextStyle.fontSize].
  /// Defaults to 1.1 matching official MTG card printing cap-height proportions.
  final double? symbolScale;

  /// Explicit override for symbol size in logical pixels.
  /// If provided, overrides [symbolScale].
  final double? symbolSize;

  /// Horizontal padding around each inline symbol. Defaults to 1.5px horizontal.
  final EdgeInsetsGeometry symbolPadding;

  /// How system font scaling behaves.
  final TextScaler? textScaler;

  /// An alternative semantics label for accessibility.
  final String? semanticsLabel;

  const ManaText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.symbolScale = 1.1,
    this.symbolSize,
    this.symbolPadding = const EdgeInsets.symmetric(horizontal: 1.5),
    this.textScaler,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle effectiveStyle = (style == null || style!.inherit)
        ? defaultTextStyle.style.merge(style)
        : style!;
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(const TextStyle(fontWeight: FontWeight.bold));
    }

    final spans = ManaTextParser.parse(
      text: text,
      baseStyle: effectiveStyle,
      symbolSize: symbolSize,
      scaleFactor: symbolScale ?? 1.1,
      symbolPadding: symbolPadding,
    );

    return Text.rich(
      TextSpan(children: spans, style: effectiveStyle),
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      textScaler: textScaler,
      semanticsLabel: semanticsLabel,
    );
  }
}

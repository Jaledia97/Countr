import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Utility class to calculate the physical bounding perimeter of a detected card
/// from Google ML Kit [TextBlock] recognitions and map the coordinates from image
/// sensor space to Flutter screen coordinate space with orientation compensation.
class CardPerimeterCalculator {
  /// Calculates the enclosing bounding rectangle for a collection of [TextBlock]s
  /// with horizontal and vertical padding to capture the physical card perimeter.
  ///
  /// Returns `null` if [blocks] is empty or no valid bounding boxes are found.
  static Rect? calculatePerimeter(
    List<TextBlock> blocks, {
    Size? imageSize,
    double padXPercent = 0.08,
    double padYPercent = 0.12,
  }) {
    if (blocks.isEmpty) return null;

    double minLeft = double.infinity;
    double minTop = double.infinity;
    double maxRight = double.negativeInfinity;
    double maxBottom = double.negativeInfinity;
    int validBlocks = 0;

    for (final block in blocks) {
      final box = block.boundingBox;
      if (box.width <= 0 || box.height <= 0) continue;
      validBlocks++;

      if (box.left < minLeft) minLeft = box.left;
      if (box.top < minTop) minTop = box.top;
      if (box.right > maxRight) maxRight = box.right;
      if (box.bottom > maxBottom) maxBottom = box.bottom;
    }

    if (validBlocks == 0 || minLeft >= maxRight || minTop >= maxBottom) {
      return null;
    }

    final rawWidth = maxRight - minLeft;
    final rawHeight = maxBottom - minTop;

    final padX = rawWidth * padXPercent;
    final padY = rawHeight * padYPercent;

    double left = minLeft - padX;
    double top = minTop - padY;
    double right = maxRight + padX;
    double bottom = maxBottom + padY;

    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      left = left.clamp(0.0, imageSize.width);
      top = top.clamp(0.0, imageSize.height);
      right = right.clamp(0.0, imageSize.width);
      bottom = bottom.clamp(0.0, imageSize.height);
    }

    if (left >= right || top >= bottom) {
      return null;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Maps a rectangle from camera image sensor coordinates to Flutter screen pixels,
  /// accounting for scaling and centering according to the specified [BoxFit].
  static Rect mapImageRectToScreen({
    required Rect imageRect,
    required Size imageSize,
    required Size screenSize,
    BoxFit fit = BoxFit.cover,
    bool clampToScreen = false,
  }) {
    if (imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        screenSize.width <= 0 ||
        screenSize.height <= 0) {
      return imageRect;
    }

    final double scale;
    switch (fit) {
      case BoxFit.contain:
        scale = math.min(
          screenSize.width / imageSize.width,
          screenSize.height / imageSize.height,
        );
        break;
      case BoxFit.fitWidth:
        scale = screenSize.width / imageSize.width;
        break;
      case BoxFit.fitHeight:
        scale = screenSize.height / imageSize.height;
        break;
      case BoxFit.cover:
      default:
        scale = math.max(
          screenSize.width / imageSize.width,
          screenSize.height / imageSize.height,
        );
        break;
    }

    final scaledWidth = imageSize.width * scale;
    final scaledHeight = imageSize.height * scale;

    final offsetX = (screenSize.width - scaledWidth) / 2.0;
    final offsetY = (screenSize.height - scaledHeight) / 2.0;

    double left = imageRect.left * scale + offsetX;
    double top = imageRect.top * scale + offsetY;
    double right = imageRect.right * scale + offsetX;
    double bottom = imageRect.bottom * scale + offsetY;

    if (clampToScreen) {
      left = left.clamp(0.0, screenSize.width);
      top = top.clamp(0.0, screenSize.height);
      right = right.clamp(0.0, screenSize.width);
      bottom = bottom.clamp(0.0, screenSize.height);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Adjusts image dimensions to account for 90 or 270 degree sensor/device orientation.
  static Size getUprightImageSize({
    required Size rawSize,
    InputImageRotation? rotation,
  }) {
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      return Size(rawSize.height, rawSize.width);
    }
    return rawSize;
  }

  /// Clamps a mapped screen-space rectangle within the visible screen area.
  static Rect clampRectToScreen(Rect rect, Size screenSize) {
    return Rect.fromLTRB(
      rect.left.clamp(0.0, screenSize.width),
      rect.top.clamp(0.0, screenSize.height),
      rect.right.clamp(0.0, screenSize.width),
      rect.bottom.clamp(0.0, screenSize.height),
    );
  }
}

import 'dart:isolate';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'camera_frame_dto.dart';

class ScannerWorkerIsolate {
  /// Dynamic contour area floor: math.max(5000.0, 0.015 * (width * height)).
  static double calculateMinContourArea(int width, int height) {
    return math.max(5000.0, 0.015 * (width * height));
  }

  /// Calculates normalized ratio = min(w, h) / max(w, h) <= 1.0.
  static double normalizeAspectRatio(double width, double height) {
    if (width <= 0 || height <= 0) return 0.0;
    return (width < height) ? width / height : height / width;
  }

  /// Evaluates whether normalized aspect ratio is within perspective tolerance (±0.22) of [targetAspectRatio].
  /// Standard TCG valid range: [0.50, 0.93].
  static bool isAspectMatch(
    double width,
    double height,
    double targetAspectRatio, {
    double tolerance = 0.22,
  }) {
    final ratio = normalizeAspectRatio(width, height);
    if (ratio <= 0) return false;
    return (ratio - targetAspectRatio).abs() <= tolerance;
  }

  /// Validates whether a contour vertex count is a quadrilateral or rounded corner (4 to 8 vertices).
  static bool isSupportedVertexCount(int vertexCount) {
    return vertexCount >= 4 && vertexCount <= 8;
  }

  static Future<(Uint8List?, Uint8List?, List<double>?)> processFrame(
    dynamic frameOrImage,
    double targetAspectRatio,
  ) async {
    final CameraFrameDto frame;
    if (frameOrImage is CameraFrameDto) {
      frame = frameOrImage;
    } else if (frameOrImage is CameraImage) {
      frame = CameraFrameDto.fromCameraImage(frameOrImage);
    } else {
      throw ArgumentError(
        'Expected CameraFrameDto or CameraImage, got ${frameOrImage.runtimeType}',
      );
    }

    return await Isolate.run(() {
      try {
        final contiguousBytes = frame.extractContiguousBytes();
        cv.Mat gray;
        if (frame.formatGroup == ImageFormatGroup.bgra8888) {
          final src = cv.Mat.fromList(
            frame.height,
            frame.width,
            cv.MatType.CV_8UC4,
            contiguousBytes,
          );
          gray = cv.cvtColor(src, cv.COLOR_BGRA2GRAY);
        } else if (frame.formatGroup == ImageFormatGroup.yuv420 ||
            frame.formatGroup == ImageFormatGroup.nv21) {
          gray = cv.Mat.fromList(
            frame.height,
            frame.width,
            cv.MatType.CV_8UC1,
            contiguousBytes,
          );
        } else {
          return (null, null, null);
        }

        final blurred = cv.gaussianBlur(gray, (5, 5), 0);
        final edges = cv.canny(blurred, 50, 150);

        final contours = cv.findContours(
          edges,
          cv.RETR_EXTERNAL,
          cv.CHAIN_APPROX_SIMPLE,
        ).$1;

        List<cv.Point2f>? bestCorners;
        double maxArea = 0;
        final minContourArea =
            calculateMinContourArea(frame.width, frame.height);

        for (int i = 0; i < contours.length; i++) {
          final contour = contours[i];
          final area = cv.contourArea(contour);
          if (area < minContourArea) continue;

          final peri = cv.arcLength(contour, true);
          final approx = cv.approxPolyDP(contour, 0.02 * peri, true);

          // Support quadrilaterals (4) and rounded corners (5 to 8 vertices)
          if (isSupportedVertexCount(approx.length)) {
            final rect = cv.minAreaRect(approx);
            final rectWidth = rect.size.width;
            final rectHeight = rect.size.height;
            if (isAspectMatch(
              rectWidth,
              rectHeight,
              targetAspectRatio,
              tolerance: 0.22,
            )) {
              if (area > maxArea) {
                maxArea = area;
                if (approx.length == 4) {
                  bestCorners = approx
                      .map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble()))
                      .toList();
                } else {
                  // Extract true 4 corners of minimal bounding box around rounded corners
                  bestCorners = rect.points.toList();
                }
              }
            }
          }
        }

        if (bestCorners != null) {
          bestCorners.sort((a, b) => (a.y + a.x).compareTo(b.y + b.x));
          final tl = bestCorners[0];
          final br = bestCorners[3];

          final remaining = [bestCorners[1], bestCorners[2]];
          remaining.sort((a, b) => a.x.compareTo(b.x));
          final bl = remaining[0];
          final tr = remaining[1];

          final width = 600.0;
          final height = width / targetAspectRatio;

          final srcPts = cv.VecPoint2f.fromList([
            cv.Point2f(tl.x, tl.y),
            cv.Point2f(tr.x, tr.y),
            cv.Point2f(br.x, br.y),
            cv.Point2f(bl.x, bl.y),
          ]);

          final dstPts = cv.VecPoint2f.fromList([
            cv.Point2f(0.0, 0.0),
            cv.Point2f(width, 0.0),
            cv.Point2f(width, height),
            cv.Point2f(0.0, height),
          ]);

          final transform = cv.getPerspectiveTransform2f(srcPts, dstPts);
          final warped = cv.warpPerspective(
            gray,
            transform,
            (width.toInt(), height.toInt()),
          );

          final resized = cv.resize(warped, (9, 8));
          final jpgBytes = cv.imencode('.jpg', warped).$2;

          final corners = [
            tl.x,
            tl.y,
            tr.x,
            tr.y,
            br.x,
            br.y,
            bl.x,
            bl.y,
          ];
          return (resized.data, jpgBytes, corners);
        }

        return (null, null, null);
      } catch (e, stackTrace) {
        debugPrint(
            '[ScannerWorkerIsolate] Frame processing failed: $e\n$stackTrace');
        return (null, null, null);
      }
    });
  }
}

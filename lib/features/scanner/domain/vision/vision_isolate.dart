import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ScannerWorkerIsolate {
  static Future<(Uint8List?, Uint8List?, List<double>?)> processFrame(
      CameraImage image, double targetAspectRatio) async {
    return await Isolate.run(() {
      try {
        cv.Mat src;
        if (image.format.group == ImageFormatGroup.bgra8888) {
          src = cv.Mat.fromList(
            image.height,
            image.width,
            cv.MatType.CV_8UC4,
            image.planes[0].bytes,
          );
        } else if (image.format.group == ImageFormatGroup.yuv420) {
          src = cv.Mat.fromList(
            image.height,
            image.width,
            cv.MatType.CV_8UC1,
            image.planes[0].bytes,
          );
        } else {
          return (null, null, null);
        }

        cv.Mat gray = src;
        if (src.channels == 4) {
          gray = cv.cvtColor(src, cv.COLOR_BGRA2GRAY);
        }

        final blurred = cv.gaussianBlur(gray, (5, 5), 0);
        final edges = cv.canny(blurred, 50, 150);

        final contours = cv.findContours(
            edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE).$1;

        List<cv.Point>? bestApprox;
        double maxArea = 0;

        for (int i = 0; i < contours.length; i++) {
          final contour = contours[i];
          final area = cv.contourArea(contour);
          if (area < 10000) continue;

          final peri = cv.arcLength(contour, true);
          final approx = cv.approxPolyDP(contour, 0.02 * peri, true);

          if (approx.length == 4) {
            final rect = cv.minAreaRect(approx);
            final rectWidth = rect.size.width;
            final rectHeight = rect.size.height;
            if (rectWidth > 0 && rectHeight > 0) {
              final ratio = (rectWidth < rectHeight)
                  ? rectWidth / rectHeight
                  : rectHeight / rectWidth;

              if ((ratio - targetAspectRatio).abs() < 0.15) {
                if (area > maxArea) {
                  maxArea = area;
                  bestApprox = approx.toList();
                }
              }
            }
          }
        }

        if (bestApprox != null) {
          bestApprox.sort((a, b) => (a.y + a.x).compareTo(b.y + b.x));
          final tl = bestApprox[0];
          final br = bestApprox[3];

          final remaining = [bestApprox[1], bestApprox[2]];
          remaining.sort((a, b) => a.x.compareTo(b.x));
          final bl = remaining[0];
          final tr = remaining[1];

          final width = 600.0;
          final height = width / targetAspectRatio;
          
          final srcPts = cv.VecPoint2f.fromList([
            cv.Point2f(tl.x.toDouble(), tl.y.toDouble()),
            cv.Point2f(tr.x.toDouble(), tr.y.toDouble()),
            cv.Point2f(br.x.toDouble(), br.y.toDouble()),
            cv.Point2f(bl.x.toDouble(), bl.y.toDouble()),
          ]);
          
          final dstPts = cv.VecPoint2f.fromList([
            cv.Point2f(0.0, 0.0),
            cv.Point2f(width, 0.0),
            cv.Point2f(width, height),
            cv.Point2f(0.0, height),
          ]);

          final transform = cv.getPerspectiveTransform2f(srcPts, dstPts);
          final warped = cv.warpPerspective(gray, transform, (width.toInt(), height.toInt()));
          
          final resized = cv.resize(warped, (9, 8));
          final jpgBytes = cv.imencode('.jpg', warped).$2;
          
          final corners = [
            tl.x.toDouble(), tl.y.toDouble(),
            tr.x.toDouble(), tr.y.toDouble(),
            br.x.toDouble(), br.y.toDouble(),
            bl.x.toDouble(), bl.y.toDouble(),
          ];
          return (resized.data, jpgBytes, corners);
        }

        return (null, null, null);
      } catch (e) {
        return (null, null, null);
      }
    });
  }
}

import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Lightweight, thread-safe camera frame DTO transferred across [Isolate.run].
class CameraFrameDto {
  final Uint8List planeBytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final ImageFormatGroup formatGroup;

  const CameraFrameDto({
    required this.planeBytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.formatGroup,
  });

  /// Extracts Plane 0 from [CameraImage] on the caller thread with zero unnecessary plane copies.
  factory CameraFrameDto.fromCameraImage(CameraImage image) {
    final plane = image.planes.isNotEmpty ? image.planes.first : null;
    return CameraFrameDto(
      planeBytes: plane != null ? plane.bytes : Uint8List(0),
      width: image.width,
      height: image.height,
      bytesPerRow: plane != null ? plane.bytesPerRow : image.width,
      formatGroup: image.format.group,
    );
  }

  /// Extracts contiguous bytes row-by-row respecting [bytesPerRow].
  /// Strips padding bytes cleanly for BGRA8888, YUV420, and NV21.
  Uint8List extractContiguousBytes() {
    if (formatGroup == ImageFormatGroup.bgra8888) {
      final int rowBytes = width * 4;
      if (bytesPerRow == rowBytes && planeBytes.length == width * height * 4) {
        return planeBytes;
      }
      final contiguous = Uint8List(width * height * 4);
      int destOffset = 0;
      final stride = bytesPerRow > 0 ? bytesPerRow : rowBytes;
      for (int row = 0; row < height; row++) {
        final srcOffset = row * stride;
        if (srcOffset + rowBytes <= planeBytes.length) {
          contiguous.setRange(destOffset, destOffset + rowBytes, planeBytes, srcOffset);
        }
        destOffset += rowBytes;
      }
      return contiguous;
    }

    // Android NV21 / YUV420 / single-channel luminance
    if (bytesPerRow == width && planeBytes.length == width * height) {
      return planeBytes;
    }

    final contiguous = Uint8List(width * height);
    int destOffset = 0;
    final stride = bytesPerRow > 0 ? bytesPerRow : width;
    for (int row = 0; row < height; row++) {
      final srcOffset = row * stride;
      if (srcOffset + width <= planeBytes.length) {
        contiguous.setRange(destOffset, destOffset + width, planeBytes, srcOffset);
      }
      destOffset += width;
    }
    return contiguous;
  }
}

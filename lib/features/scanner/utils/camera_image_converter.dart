import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Utility to convert a camera image stream ([CameraImage]) into
/// Google ML Kit's [InputImage] across iOS and Android.
class CameraImageConverter {
  /// Converts a [CameraImage] into [InputImage] with appropriate planes,
  /// rotation compensation, and color formats.
  static InputImage? toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    DeviceOrientation? deviceOrientation,
  }) {
    final rotation = calculateRotation(camera, deviceOrientation);
    final format = getInputImageFormat(image);
    if (format == null) return null;

    final Uint8List bytes;
    if (Platform.isIOS || image.format.group == ImageFormatGroup.bgra8888) {
      bytes = image.planes.first.bytes;
    } else {
      // If CameraX provided single-plane NV21 or BGRA:
      if (image.planes.length == 1) {
        bytes = image.planes.first.bytes;
      } else {
        // Multi-plane YUV420_888 to NV21 conversion
        bytes = _convertYuv420ToNv21(image);
      }
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// Converts multi-plane Android YUV420_888 to contiguous NV21 bytes
  /// with proper stride padding and UV interleaving.
  static Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + (numPixels ~/ 2));

    // 1. Copy Y plane (handling row padding if bytesPerRow != width)
    int idY = 0;
    final yRowStride = yPlane.bytesPerRow;
    for (int row = 0; row < height; row++) {
      final rowOffset = row * yRowStride;
      if (rowOffset + width <= yBuffer.length) {
        nv21.setRange(idY, idY + width, yBuffer, rowOffset);
      }
      idY += width;
    }

    // 2. Interleave V and U planes (NV21 format: V0, U0, V1, U1...)
    final int vRowStride = vPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 2;
    final int uPixelStride = uPlane.bytesPerPixel ?? 2;
    int idUV = numPixels;
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      final vRowOffset = row * vRowStride;
      final uRowOffset = row * uRowStride;
      for (int col = 0; col < uvWidth; col++) {
        final vIndex = vRowOffset + (col * vPixelStride);
        final uIndex = uRowOffset + (col * uPixelStride);
        if (vIndex < vBuffer.length && uIndex < uBuffer.length && idUV + 1 < nv21.length) {
          nv21[idUV++] = vBuffer[vIndex];
          nv21[idUV++] = uBuffer[uIndex];
        }
      }
    }

    return nv21;
  }

  /// Determines the ML Kit [InputImageFormat] from [CameraImage].
  static InputImageFormat? getInputImageFormat(CameraImage image) {
    if (Platform.isIOS || image.format.group == ImageFormatGroup.bgra8888) {
      return InputImageFormat.bgra8888;
    } else if (Platform.isAndroid ||
        image.format.group == ImageFormatGroup.nv21 ||
        image.format.group == ImageFormatGroup.yuv420) {
      return InputImageFormat.nv21;
    }
    return InputImageFormatValue.fromRawValue(image.format.raw);
  }

  /// Calculates the proper [InputImageRotation] based on camera sensor orientation
  /// and device orientation.
  static InputImageRotation calculateRotation(
    CameraDescription camera,
    DeviceOrientation? deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    int rotationCompensation;

    if (deviceOrientation == null) {
      rotationCompensation = 0;
    } else {
      switch (deviceOrientation) {
        case DeviceOrientation.portraitUp:
          rotationCompensation = 0;
          break;
        case DeviceOrientation.landscapeLeft:
          rotationCompensation = 90;
          break;
        case DeviceOrientation.portraitDown:
          rotationCompensation = 180;
          break;
        case DeviceOrientation.landscapeRight:
          rotationCompensation = 270;
          break;
      }
    }

    int rotation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotation = (sensorOrientation - rotationCompensation + 360) % 360;
    }

    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}

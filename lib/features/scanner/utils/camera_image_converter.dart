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
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// Determines the ML Kit [InputImageFormat] from [CameraImage].
  static InputImageFormat? getInputImageFormat(CameraImage image) {
    if (Platform.isIOS || image.format.group == ImageFormatGroup.bgra8888) {
      return InputImageFormat.bgra8888;
    } else if (Platform.isAndroid || image.format.group == ImageFormatGroup.yuv420) {
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

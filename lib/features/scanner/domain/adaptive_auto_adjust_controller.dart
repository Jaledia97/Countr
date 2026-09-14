import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Manages the Adaptive Auto-Adjust glare reduction state machine.
/// When cards in plastic/foil sleeves cause reflections, this controller
/// incrementally steps down exposure (-0.5, -1.0, -1.5) after 1.5 seconds
/// of non-matching frames and triggers a focus pulse.
/// Once a match is secured, exposure resets immediately to 0.0.
class AdaptiveAutoAdjustController {
  final CameraController? cameraController;
  final Duration noMatchThreshold;
  final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<double> exposureOffsetNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> currentStepNotifier = ValueNotifier<int>(0);

  DateTime? _lastStepTime;
  int _step = 0;

  static const List<double> exposureSteps = [0.0, -0.5, -1.0, -1.5];

  AdaptiveAutoAdjustController({
    this.cameraController,
    this.noMatchThreshold = const Duration(milliseconds: 1500),
    bool initiallyEnabled = true,
  }) {
    isEnabledNotifier.value = initiallyEnabled;
    _lastStepTime = DateTime.now();
  }

  bool get isEnabled => isEnabledNotifier.value;
  double get currentOffset => exposureOffsetNotifier.value;
  int get currentStep => _step;

  void toggle() {
    setEnabled(!isEnabled);
  }

  void setEnabled(bool enabled) {
    isEnabledNotifier.value = enabled;
    if (!enabled) {
      reset(resetHardware: true);
    } else {
      _lastStepTime = DateTime.now();
    }
  }

  /// Process the result of a scanned frame.
  /// If [matched] is true, resets exposure and timer to baseline.
  /// If [matched] is false and auto-adjust is enabled, checks if [noMatchThreshold]
  /// has elapsed without progress. If so, steps down exposure and pulses focus.
  Future<void> onFrameResult({required bool matched}) async {
    if (!isEnabled) return;

    if (matched) {
      if (_step != 0) {
        await reset(resetHardware: true);
      } else {
        _lastStepTime = DateTime.now();
      }
      return;
    }

    final now = DateTime.now();
    if (_lastStepTime == null) {
      _lastStepTime = now;
      return;
    }

    if (now.difference(_lastStepTime!) >= noMatchThreshold) {
      if (_step < exposureSteps.length - 1) {
        _step++;
        final newOffset = exposureSteps[_step];
        exposureOffsetNotifier.value = newOffset;
        currentStepNotifier.value = _step;
        _lastStepTime = now;

        await _applyHardwareAdjustments(newOffset);
      }
    }
  }

  Future<void> _applyHardwareAdjustments(double offset) async {
    if (cameraController == null || !cameraController!.value.isInitialized) return;

    try {
      final minExp = await cameraController!.getMinExposureOffset();
      final maxExp = await cameraController!.getMaxExposureOffset();
      final stepSize = await cameraController!.getExposureOffsetStepSize();

      var target = offset;
      if (target < minExp) target = minExp;
      if (target > maxExp) target = maxExp;

      if (stepSize > 0) {
        target = (target / stepSize).round() * stepSize;
      }

      await cameraController!.setExposureOffset(target);
      await cameraController!.setFocusMode(FocusMode.auto);
    } catch (_) {
      // Silently ignore if device/platform does not support exposure or focus controls
    }
  }

  Future<void> reset({bool resetHardware = false}) async {
    _step = 0;
    _lastStepTime = DateTime.now();
    exposureOffsetNotifier.value = 0.0;
    currentStepNotifier.value = 0;

    if (resetHardware && cameraController != null && cameraController!.value.isInitialized) {
      try {
        await cameraController!.setExposureOffset(0.0);
        await cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
    }
  }

  void dispose() {
    isEnabledNotifier.dispose();
    exposureOffsetNotifier.dispose();
    currentStepNotifier.dispose();
  }
}

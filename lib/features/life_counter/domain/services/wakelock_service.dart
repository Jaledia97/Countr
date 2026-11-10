// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/services.dart';

/// Service managing device screen wake lock during active matches (R4.4).
class WakelockService {
  static const MethodChannel _channel = MethodChannel('countr/wakelock');
  static bool _enabled = false;

  /// Whether the wake lock is currently active.
  static bool get isEnabled => _enabled;

  /// Enables the wake lock to keep the display awake.
  static Future<void> enable() async {
    _enabled = true;
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {
      // Gracefully handles missing platform channels in test environments.
    }
  }

  /// Disables the wake lock, restoring normal display timeout.
  static Future<void> disable() async {
    _enabled = false;
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {
      // Gracefully handles missing platform channels in test environments.
    }
  }

  /// Sets wake lock status according to [enabled].
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }
}

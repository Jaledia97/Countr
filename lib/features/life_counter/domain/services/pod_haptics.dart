// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/services.dart';

/// Configurable haptic feedback utility for life counter interactions (R4.4).
class PodHaptics {
  /// Global toggle gating all life counter haptic vibrations.
  static bool enabled = true;

  static Future<void> lightImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> mediumImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> selectionClick() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> heavyImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}

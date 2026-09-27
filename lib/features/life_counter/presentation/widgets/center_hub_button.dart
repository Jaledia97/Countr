// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central crossroads floating hub button (Feature 24) providing neutral,
/// non-blocking access to Table Utilities, Dice/Coin Randomizers, and Lobby Settings.
///
/// Sized to 48x48px with dark glassmorphic styling, luminous border,
/// circular touch splash, and strict boundary hit-testing to prevent interference
/// with adjacent player quadrant touch zones.
class CenterHubButton extends StatelessWidget {
  /// Callback triggered when the center hub button is tapped.
  final VoidCallback? onPressed;

  /// Diameter of the circular button. Defaults to 48.0 (standard 48–56px).
  final double size;

  /// Icon displayed in the center. Defaults to [Icons.casino].
  final IconData icon;

  /// Color of the center icon. Defaults to [Colors.amberAccent].
  final Color iconColor;

  /// Size of the center icon. Defaults to 24.0.
  final double iconSize;

  /// Background color of the circular glassmorphic container.
  /// Defaults to deep dark slate `Color(0xFF2C2C40)`.
  final Color backgroundColor;

  /// Border color outlining the circular button. Defaults to [Colors.white38].
  final Color borderColor;

  /// Border width. Defaults to 2.0.
  final double borderWidth;

  /// Elevation shadow color. Defaults to [Colors.black54].
  final Color shadowColor;

  /// Tooltip message and semantic accessibility label.
  final String tooltip;

  /// Specific key for the interactive button target (for automated testing).
  final Key? buttonKey;

  const CenterHubButton({
    super.key,
    this.onPressed,
    this.size = 48.0,
    this.icon = Icons.casino,
    this.iconColor = Colors.amberAccent,
    this.iconSize = 24.0,
    this.backgroundColor = const Color(0xFF2C2C40),
    this.borderColor = Colors.white38,
    this.borderWidth = 2.0,
    this.shadowColor = Colors.black54,
    this.tooltip = 'Table Utilities & Randomizers',
    this.buttonKey = const Key('center_hub_button'),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: buttonKey,
                customBorder: const CircleBorder(),
                splashColor: iconColor.withValues(alpha: 0.3),
                highlightColor: iconColor.withValues(alpha: 0.15),
                onTap: onPressed == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onPressed!();
                      },
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: iconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

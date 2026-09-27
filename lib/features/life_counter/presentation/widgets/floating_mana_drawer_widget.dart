// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

/// Floating Mana Drawer displaying authentic WUBRGC MTG mana pips,
/// increment/decrement steppers, integrated storm counter, and a one-tap
/// "Clear Pool" button with undo support.
///
/// Features:
/// - Feature 40: Authentic WUBRGC mana pips rendered via [ManaSymbolIcon] (White, Blue,
///   Black, Red, Green, Colorless) with integer stepper controls and storm counter.
/// - Feature 41: One-tap "Clear Pool" action instantly resetting floating mana and storm
///   count with undo support (via event ledger and interactive snackbar / undo callback).
class FloatingManaDrawerWidget extends StatelessWidget {
  final PodPlayerState player;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;
  final void Function(int delta)? onStormDelta;
  final VoidCallback? onUndo;
  final bool autoCloseOnClear;

  const FloatingManaDrawerWidget({
    super.key,
    required this.player,
    this.onManaDelta,
    this.onManaClear,
    this.onStormDelta,
    this.onUndo,
    this.autoCloseOnClear = true,
  });

  static const List<String> manaColors = ['W', 'U', 'B', 'R', 'G', 'C'];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('mana_drawer_sheet_${player.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row: Title & Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Mana Pool & Storm: ${player.name}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Header Action Buttons (Undo & Clear Pool)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Optional Undo button in header
                      if (onUndo != null) ...[
                        OutlinedButton.icon(
                          key: Key('undo_pool_btn_${player.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amberAccent,
                            side: const BorderSide(color: Colors.amberAccent, width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Undo', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onUndo?.call();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],

                      // One-Tap Clear Pool Button (Feature 41)
                      ElevatedButton.icon(
                        key: Key('clear_pool_btn_${player.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text(
                          'Clear Pool',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _handleClearPool(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // WUBRGC Mana Pips & Steppers Row (Feature 40)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: manaColors.map((color) {
                final count = player.floatingMana[color] ?? 0;
                return _buildManaPip(context, color, count);
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white24, height: 24),

          // Storm Counter Display & Stepper
          _buildStormCounter(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Builds an individual WUBRGC mana column with vector symbol, value, and steppers.
  Widget _buildManaPip(BuildContext context, String color, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Genuine MTG Vector Mana Pip with glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getManaColor(color).withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ManaSymbolIcon(
              symbolCode: color,
              size: 34,
              circular: true,
              semanticLabel: _getSemanticLabel(color),
              fallbackBuilder: (ctx, code, size) => CircleAvatar(
                radius: size / 2,
                backgroundColor: _getManaColor(color),
                child: Text(
                  color,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color == 'W' ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Mana Value Display
          Text(
            '$count',
            key: Key('mana_val_${color}_${player.id}'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),

          // Stepper Buttons (- and +)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('mana_dec_${color}_${player.id}'),
                icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Decrease $color mana',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onManaDelta?.call(color, -1);
                },
              ),
              IconButton(
                key: Key('mana_inc_${color}_${player.id}'),
                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Increase $color mana',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onManaDelta?.call(color, 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the integrated Storm counter with lightning badge and steppers.
  Widget _buildStormCounter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.35), width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onStormDelta != null) ...[
              IconButton(
                key: Key('storm_dec_${player.id}'),
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.amberAccent),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onStormDelta?.call(-1);
                },
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.flash_on, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Storm Count: ${player.stormCount}',
              key: Key('storm_count_${player.id}'),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (onStormDelta != null) ...[
              const SizedBox(width: 4),
              IconButton(
                key: Key('storm_inc_${player.id}'),
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.amberAccent),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onStormDelta?.call(1);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handles the One-Tap Clear Pool action with haptics, undo snackbar, and optional auto-close.
  void _handleClearPool(BuildContext context) {
    HapticFeedback.mediumImpact();
    onManaClear?.call();

    // Trigger interactive undo snackbar if undo callback is wired
    if (onUndo != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared mana pool for ${player.name}'),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amberAccent,
            onPressed: onUndo!,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (autoCloseOnClear && Navigator.canPop(context)) {
      Navigator.maybePop(context);
    }
  }

  /// Resolves the fallback hex color for MTG mana types.
  Color _getManaColor(String color) {
    switch (color) {
      case 'W':
        return const Color(0xFFF9FAF4);
      case 'U':
        return const Color(0xFF0E68AB);
      case 'B':
        return const Color(0xFF150B00);
      case 'R':
        return const Color(0xFFD3202A);
      case 'G':
        return const Color(0xFF00733E);
      case 'C':
      default:
        return const Color(0xFFCCC2AB);
    }
  }

  /// Resolves accessible screen reader labels for assistive tech.
  String _getSemanticLabel(String color) {
    switch (color) {
      case 'W':
        return 'White mana';
      case 'U':
        return 'Blue mana';
      case 'B':
        return 'Black mana';
      case 'R':
        return 'Red mana';
      case 'G':
        return 'Green mana';
      case 'C':
        return 'Colorless mana';
      default:
        return '$color mana';
    }
  }
}

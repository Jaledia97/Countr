// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'floating_mana_drawer_widget.dart';

/// Modular Secondary Counters Bar (Features 35, 36, 37, 38).
///
/// Features:
/// - Poison / Infect counter stepper (`☠️`) with toxic emerald styling and 10-point lethal defeat banner trigger.
/// - Energy stepper (`⚡` / `{E}`).
/// - Experience stepper (`XP`).
/// - Commander Tax calculator stepper (`Tax: +(casts * 2)`).
/// - Pod-wide exclusive Monarch & Initiative token claim buttons (`👑`, `🗡`).
/// - Floating Mana Pool launcher button (`Icons.bubble_chart`).
class SecondaryCountersBar extends StatelessWidget {
  final PodPlayerState player;
  final bool isTablet;
  final void Function(String counterType, int delta)? onCounterDelta;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;

  const SecondaryCountersBar({
    super.key,
    required this.player,
    required this.isTablet,
    this.onCounterDelta,
    this.onManaDelta,
    this.onManaClear,
    this.onClaimMonarch,
    this.onClaimInitiative,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      // Poison Stepper (Feature 35)
      _buildCounterStepper(
        keyName: 'poison_${player.id}',
        label: '☠️',
        value: player.poison,
        accentColor: player.isPoisonLethal ? Colors.redAccent : Colors.greenAccent,
        onIncrement: () => onCounterDelta?.call('poison', 1),
        onDecrement: () => onCounterDelta?.call('poison', -1),
      ),
      // Energy Stepper (Feature 36)
      _buildCounterStepper(
        keyName: 'energy_${player.id}',
        label: '⚡',
        value: player.energy,
        accentColor: Colors.amberAccent,
        onIncrement: () => onCounterDelta?.call('energy', 1),
        onDecrement: () => onCounterDelta?.call('energy', -1),
      ),
      // Experience Stepper (Feature 36)
      _buildCounterStepper(
        keyName: 'xp_${player.id}',
        label: 'XP',
        value: player.experience,
        accentColor: Colors.lightBlueAccent,
        onIncrement: () => onCounterDelta?.call('xp', 1),
        onDecrement: () => onCounterDelta?.call('xp', -1),
      ),
      // Commander Tax Stepper (Feature 37)
      _buildTaxStepper(),
      // Mana Launcher
      _buildManaButton(context),
    ];

    if (isTablet) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items
              .map((w) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: w,
                  ))
              .toList(),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: items,
    );
  }

  Widget _buildCounterStepper({
    required String keyName,
    required String label,
    required int value,
    Color? accentColor,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: Key('dec_$keyName'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onDecrement();
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$label $value',
                key: Key('val_$keyName'),
                style: TextStyle(
                  color: accentColor ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            GestureDetector(
              key: Key('inc_$keyName'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onIncrement();
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.add_circle_outline,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxStepper() {
    final taxValue = player.commanderTax * 2;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.shade900.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: Key('dec_tax_${player.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onCounterDelta?.call('commanderTax', -1);
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Tax: +$taxValue',
                key: Key('val_tax_${player.id}'),
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            GestureDetector(
              key: Key('inc_tax_${player.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onCounterDelta?.call('commanderTax', 1);
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.add_circle_outline,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManaButton(BuildContext context) {
    return IconButton(
      key: Key('mana_drawer_btn_${player.id}'),
      tooltip: 'Floating Mana & Storm',
      padding: isTablet ? const EdgeInsets.all(8) : const EdgeInsets.all(4),
      constraints: isTablet
          ? const BoxConstraints(minWidth: 48, minHeight: 48)
          : const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: const Icon(
        Icons.bubble_chart,
        color: Colors.cyanAccent,
        size: 20,
      ),
      onPressed: () => _openManaModal(context),
    );
  }

  void _openManaModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return FloatingManaDrawerWidget(
          player: player,
          onManaDelta: onManaDelta,
          onManaClear: onManaClear,
        );
      },
    );
  }
}

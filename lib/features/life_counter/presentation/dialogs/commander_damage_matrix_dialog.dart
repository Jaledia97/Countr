// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';

/// Modal dialog for inspecting and precisely adjusting Commander Damage taken
/// from each opponent, including support for Partner commanders (Partner A and Partner B).
class CommanderDamageMatrixDialog extends StatefulWidget {
  final PodPlayerState targetPlayer;
  final List<PodPlayerState> opponents;
  final void Function(String opponentId, int delta) onDamageDelta;
  final String? preFocusedOpponentId;

  const CommanderDamageMatrixDialog({
    super.key,
    required this.targetPlayer,
    required this.opponents,
    required this.onDamageDelta,
    this.preFocusedOpponentId,
  });

  /// Presents the Commander Damage Matrix modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required PodPlayerState targetPlayer,
    required List<PodPlayerState> opponents,
    required void Function(String opponentId, int delta) onDamageDelta,
    String? preFocusedOpponentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161922),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CommanderDamageMatrixDialog(
        targetPlayer: targetPlayer,
        opponents: opponents,
        onDamageDelta: onDamageDelta,
        preFocusedOpponentId: preFocusedOpponentId,
      ),
    );
  }

  @override
  State<CommanderDamageMatrixDialog> createState() =>
      _CommanderDamageMatrixDialogState();
}

class _CommanderDamageMatrixDialogState
    extends State<CommanderDamageMatrixDialog> {
  final Set<String> _expandedPartners = {};

  @override
  void initState() {
    super.initState();
    // Auto-expand partner if damage already exists
    for (final opp in widget.opponents) {
      final partnerDmg =
          widget.targetPlayer.commanderDamageTaken['${opp.id}_partner'] ?? 0;
      if (partnerDmg > 0) {
        _expandedPartners.add(opp.id);
      }
    }
  }

  void _togglePartner(String oppId) {
    setState(() {
      if (_expandedPartners.contains(oppId)) {
        _expandedPartners.remove(oppId);
      } else {
        _expandedPartners.add(oppId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetPlayer;

    return SafeArea(
      child: Container(
        key: Key('cmd_damage_dialog_${target.id}'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
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

            // Header
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.redAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Commander Damage on ${target.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Current Life: ${target.life}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('cmd_damage_dialog_close'),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),

            // List of opponents
            Expanded(
              child: widget.opponents.isEmpty
                  ? const Center(
                      child: Text(
                        'No opponents in match.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: widget.opponents.length,
                      separatorBuilder: (ctx, idx) =>
                          const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final opp = widget.opponents[idx];
                        return _buildOpponentCard(target, opp);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentCard(PodPlayerState target, PodPlayerState opp) {
    final dmgA = target.commanderDamageTaken[opp.id] ?? 0;
    final dmgB = target.commanderDamageTaken['${opp.id}_partner'] ?? 0;
    final isLethalA = dmgA >= 21;
    final isLethalB = dmgB >= 21;
    final hasPartner = _expandedPartners.contains(opp.id) || dmgB > 0;

    return Container(
      key: Key('cmd_damage_card_${opp.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isLethalA || isLethalB)
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : const Color(0xFF1F2430),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isLethalA || isLethalB)
              ? Colors.redAccent.withValues(alpha: 0.8)
              : Colors.white12,
          width: (isLethalA || isLethalB) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Opponent Header Row
          Row(
            children: [
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: (opp.commanderArtCropUrl != null &&
                        opp.commanderArtCropUrl!.isNotEmpty)
                    ? CountrCachedImage(
                        imageUrl: opp.commanderArtCropUrl!,
                        fit: BoxFit.cover,
                        errorWidget: Center(
                          child: Text(
                            opp.name.isNotEmpty ? opp.name[0] : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          opp.name.isNotEmpty ? opp.name[0] : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              const SizedBox(width: 10),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opp.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (opp.commanderName != null &&
                        opp.commanderName!.isNotEmpty)
                      Text(
                        opp.commanderName!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Partner Toggle Button
              TextButton.icon(
                key: Key('cmd_partner_toggle_${opp.id}'),
                onPressed: () => _togglePartner(opp.id),
                icon: Icon(
                  hasPartner
                      ? Icons.people_alt_rounded
                      : Icons.person_add_alt_rounded,
                  size: 16,
                  color: hasPartner ? Colors.amberAccent : Colors.white60,
                ),
                label: Text(
                  hasPartner ? 'Partner ON' : '+ Partner',
                  style: TextStyle(
                    color: hasPartner ? Colors.amberAccent : Colors.white60,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Main Commander (Partner A) Stepper
          _buildDamageStepper(
            title: hasPartner ? 'Commander 1 (Primary)' : 'Commander Damage',
            damage: dmgA,
            isLethal: isLethalA,
            decKey: Key('cmd_damage_dec_${target.id}_from_${opp.id}'),
            valKey: Key('cmd_damage_val_${target.id}_from_${opp.id}'),
            incKey: Key('cmd_damage_inc_${target.id}_from_${opp.id}'),
            onDec: () {
              HapticFeedback.lightImpact();
              widget.onDamageDelta(opp.id, -1);
            },
            onInc: () {
              HapticFeedback.lightImpact();
              widget.onDamageDelta(opp.id, 1);
            },
          ),

          // Partner B Stepper (if toggled or > 0)
          if (hasPartner) ...[
            const SizedBox(height: 8),
            _buildDamageStepper(
              title: 'Commander 2 (Partner)',
              damage: dmgB,
              isLethal: isLethalB,
              decKey:
                  Key('cmd_damage_dec_${target.id}_from_${opp.id}_partner'),
              valKey:
                  Key('cmd_damage_val_${target.id}_from_${opp.id}_partner'),
              incKey:
                  Key('cmd_damage_inc_${target.id}_from_${opp.id}_partner'),
              onDec: () {
                HapticFeedback.lightImpact();
                widget.onDamageDelta('${opp.id}_partner', -1);
              },
              onInc: () {
                HapticFeedback.lightImpact();
                widget.onDamageDelta('${opp.id}_partner', 1);
              },
            ),
          ],

          // Lethal indicator if either commander dealt 21+
          if (isLethalA || isLethalB)
            Container(
              key: Key('cmd_lethal_badge_${target.id}_from_${opp.id}'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dangerous_rounded,
                      color: Colors.redAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '21+ LETHAL COMMANDER DAMAGE',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDamageStepper({
    required String title,
    required int damage,
    required bool isLethal,
    required Key decKey,
    required Key valKey,
    required Key incKey,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLethal ? Colors.redAccent : Colors.white10,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isLethal ? Colors.redAccent : Colors.white70,
                fontSize: 12,
                fontWeight: isLethal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          IconButton(
            key: decKey,
            icon: const Icon(Icons.remove_circle_outline_rounded,
                color: Colors.white70, size: 22),
            onPressed: onDec,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Container(
            key: valKey,
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              '$damage',
              style: TextStyle(
                color: isLethal ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            key: incKey,
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Colors.white70, size: 22),
            onPressed: onInc,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

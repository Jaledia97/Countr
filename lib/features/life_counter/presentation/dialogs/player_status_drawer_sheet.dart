// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';


/// Modal bottom sheet presenting a player's seat settings, identity customization,
/// secondary counters (Poison, Commander Tax, Energy, Experience, Radiation),
/// exclusive pod tokens (Monarch, Initiative), and Vault deck linking.
class PlayerStatusDrawerSheet extends StatelessWidget {
  final PodPlayerState player;
  final List<PodPlayerState> opponents;
  final void Function(String name)? onNameChanged;
  final void Function(String color)? onColorChanged;
  final void Function(String counterType, int delta)? onCounterDelta;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;
  final void Function(DeckSummary deck)? onLinkDeck;
  final VoidCallback? onUnlinkDeck;
  final VoidCallback? onClose;

  const PlayerStatusDrawerSheet({
    super.key,
    required this.player,
    this.opponents = const [],
    this.onNameChanged,
    this.onColorChanged,
    this.onCounterDelta,
    this.onClaimMonarch,
    this.onClaimInitiative,
    this.onLinkDeck,
    this.onUnlinkDeck,
    this.onClose,
  });

  /// Presents the Player Status Drawer as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required PodPlayerState player,
    List<PodPlayerState> opponents = const [],
    void Function(String name)? onNameChanged,
    void Function(String color)? onColorChanged,
    void Function(String counterType, int delta)? onCounterDelta,
    VoidCallback? onClaimMonarch,
    VoidCallback? onClaimInitiative,
    void Function(DeckSummary deck)? onLinkDeck,
    VoidCallback? onUnlinkDeck,
    VoidCallback? onClose,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141721),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: PlayerStatusDrawerContent(
              player: player,
              opponents: opponents,
              onNameChanged: onNameChanged,
              onColorChanged: onColorChanged,
              onCounterDelta: onCounterDelta,
              onClaimMonarch: onClaimMonarch,
              onClaimInitiative: onClaimInitiative,
              onLinkDeck: onLinkDeck,
              onUnlinkDeck: onUnlinkDeck,
              onClose: () {
                onClose?.call();
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlayerStatusDrawerContent(
      player: player,
      opponents: opponents,
      onNameChanged: onNameChanged,
      onColorChanged: onColorChanged,
      onCounterDelta: onCounterDelta,
      onClaimMonarch: onClaimMonarch,
      onClaimInitiative: onClaimInitiative,
      onLinkDeck: onLinkDeck,
      onUnlinkDeck: onUnlinkDeck,
      onClose: onClose,
    );
  }
}

/// Embeddable content component for player status controls, used both in modal sheets
/// and inside phone collapsible drawer panels.
class PlayerStatusDrawerContent extends StatefulWidget {
  final PodPlayerState player;
  final List<PodPlayerState> opponents;
  final void Function(String name)? onNameChanged;
  final void Function(String color)? onColorChanged;
  final void Function(String counterType, int delta)? onCounterDelta;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;
  final void Function(DeckSummary deck)? onLinkDeck;
  final VoidCallback? onUnlinkDeck;
  final VoidCallback? onClose;

  const PlayerStatusDrawerContent({
    super.key,
    required this.player,
    this.opponents = const [],
    this.onNameChanged,
    this.onColorChanged,
    this.onCounterDelta,
    this.onClaimMonarch,
    this.onClaimInitiative,
    this.onLinkDeck,
    this.onUnlinkDeck,
    this.onClose,
  });

  @override
  State<PlayerStatusDrawerContent> createState() =>
      _PlayerStatusDrawerContentState();
}

class _PlayerStatusDrawerContentState extends State<PlayerStatusDrawerContent> {
  late TextEditingController _nameController;

  static const _presetColors = [
    ('cyan', Colors.cyanAccent),
    ('blue', Colors.blueAccent),
    ('red', Colors.redAccent),
    ('green', Colors.greenAccent),
    ('amber', Colors.amberAccent),
    ('purple', Colors.purpleAccent),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.player.name);
  }

  @override
  void didUpdateWidget(covariant PlayerStatusDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.name != widget.player.name &&
        _nameController.text != widget.player.name) {
      _nameController.text = widget.player.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openDeckPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141820),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Link Vault Deck',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No saved decks found in Vault.\nCreate decks in Deck Builder first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Icon(Icons.person_pin_rounded,
                  color: Colors.amberAccent.shade200, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${player.name} — Status & Settings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  key: Key('drawer_close_button_${player.id}'),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Name Editing Input
          TextField(
            key: Key('player_name_input_${player.id}'),
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Player / Commander Name',
              labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
              filled: true,
              fillColor: Colors.black38,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check, size: 18, color: Colors.greenAccent),
                onPressed: () =>
                    widget.onNameChanged?.call(_nameController.text.trim()),
              ),
            ),
            onSubmitted: (val) => widget.onNameChanged?.call(val.trim()),
            onChanged: (val) => widget.onNameChanged?.call(val.trim()),
          ),
          const SizedBox(height: 12),

          // 2. Profile Color Picker Circles
          Row(
            children: [
              const Text(
                'Theme:',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _presetColors.map((tuple) {
                    final colorName = tuple.$1;
                    final colorVal = tuple.$2;
                    final isSelected =
                        player.colorTheme?.toLowerCase() == colorName;

                    return GestureDetector(
                      key: Key('color_picker_${player.id}_$colorName'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onColorChanged?.call(colorName);
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.black45,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorVal.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Vault Deck Link Section
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12, width: 0.8),
            ),
            child: player.deckId == null
                ? Row(
                    children: [
                      const Icon(Icons.style_outlined,
                          color: Colors.white54, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No Vault deck linked',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                      ElevatedButton.icon(
                        key: Key('link_vault_deck_button_${player.id}'),
                        onPressed: () => _openDeckPicker(context),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('Link Deck',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent.shade700,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Commander art thumbnail
                      if (player.commanderArtCropUrl != null &&
                          player.commanderArtCropUrl!.isNotEmpty)
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: Colors.amberAccent, width: 1),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CountrCachedImage(
                            imageUrl: player.commanderArtCropUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.commanderName ?? player.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Linked Deck Active',
                              style: TextStyle(
                                  color: Colors.amberAccent, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        key: Key('unlink_vault_deck_button_${player.id}'),
                        onPressed: widget.onUnlinkDeck,
                        icon: const Icon(Icons.link_off_rounded,
                            size: 16, color: Colors.redAccent),
                        label: const Text(
                          'Unlink',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // 4. Secondary Counter Steppers
          const Text(
            'Secondary Counters',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Wrap of counter steppers
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Poison (10+ Lethal)
              _buildCounterTile(
                title: 'Poison ☠',
                value: '${player.poison}',
                accentColor:
                    player.isPoisonLethal ? Colors.redAccent : Colors.greenAccent,
                decKey: Key('dec_poison_${player.id}'),
                valKey: Key('val_poison_${player.id}'),
                incKey: Key('inc_poison_${player.id}'),
                onDec: () => widget.onCounterDelta?.call('poison', -1),
                onInc: () => widget.onCounterDelta?.call('poison', 1),
              ),

              // Commander Tax (+2 stepper)
              _buildCounterTile(
                title: 'Commander Tax',
                value: '+${player.commanderTax * 2}',
                accentColor: Colors.purpleAccent,
                decKey: Key('dec_tax_${player.id}'),
                valKey: Key('val_tax_${player.id}'),
                incKey: Key('inc_tax_${player.id}'),
                onDec: () => widget.onCounterDelta?.call('commanderTax', -1),
                onInc: () => widget.onCounterDelta?.call('commanderTax', 1),
              ),

              // Energy
              _buildCounterTile(
                title: 'Energy ⚡',
                value: '${player.energy}',
                accentColor: Colors.amberAccent,
                decKey: Key('dec_energy_${player.id}'),
                valKey: Key('val_energy_${player.id}'),
                incKey: Key('inc_energy_${player.id}'),
                onDec: () => widget.onCounterDelta?.call('energy', -1),
                onInc: () => widget.onCounterDelta?.call('energy', 1),
              ),

              // Experience
              _buildCounterTile(
                title: 'Experience XP',
                value: '${player.experience}',
                accentColor: Colors.lightBlueAccent,
                decKey: Key('dec_xp_${player.id}'),
                valKey: Key('val_xp_${player.id}'),
                incKey: Key('inc_xp_${player.id}'),
                onDec: () => widget.onCounterDelta?.call('experience', -1),
                onInc: () => widget.onCounterDelta?.call('experience', 1),
              ),

              // Radiation (Fallout rads)
              _buildCounterTile(
                title: 'Radiation ☢',
                value: '${player.radCounters}',
                accentColor: Colors.limeAccent,
                decKey: Key('dec_rad_${player.id}'),
                valKey: Key('val_rad_${player.id}'),
                incKey: Key('inc_rad_${player.id}'),
                onDec: () => widget.onCounterDelta?.call('rad', -1),
                onInc: () => widget.onCounterDelta?.call('rad', 1),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 5. Exclusive Pod Tokens (Monarch & Initiative)
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  key: Key('toggle_monarch_${player.id}'),
                  selected: player.isMonarch,
                  label: const Text('👑 Monarch'),
                  labelStyle: TextStyle(
                    color: player.isMonarch ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  selectedColor: Colors.amber,
                  backgroundColor: Colors.white10,
                  onSelected: (_) => widget.onClaimMonarch?.call(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  key: Key('toggle_initiative_${player.id}'),
                  selected: player.hasInitiative,
                  label: const Text('🗡 Initiative'),
                  labelStyle: TextStyle(
                    color: player.hasInitiative ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  selectedColor: Colors.lightBlueAccent,
                  backgroundColor: Colors.white10,
                  onSelected: (_) => widget.onClaimInitiative?.call(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterTile({
    required String title,
    required String value,
    required Color accentColor,
    required Key decKey,
    required Key valKey,
    required Key incKey,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                key: decKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDec();
                },
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.remove_circle_outline,
                      color: Colors.white54, size: 18),
                ),
              ),
              Text(
                value,
                key: valKey,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                key: incKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onInc();
                },
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.add_circle_outline,
                      color: Colors.white54, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

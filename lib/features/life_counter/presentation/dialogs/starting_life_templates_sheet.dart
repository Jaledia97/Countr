// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/core/constants/app_colors.dart';

/// Modal bottom sheet allowing pod participants to select or customize starting life templates (Feature 45).
///
/// Features:
/// 1. Preset chips:
///    - Standard / Modern: 20 Life (`Key('preset_chip_standard')`)
///    - Brawl / Two-Headed Giant: 30 Life (`Key('preset_chip_brawl')`)
///    - Commander / EDH: 40 Life (`Key('preset_chip_commander')`)
///    - Custom (`Key('preset_chip_custom')`)
/// 2. Direct custom input and +/- stepper buttons (`Key('life_dec_btn')`, `Key('life_inc_btn')`).
/// 3. Validates life range between 1 and 999.
/// 4. Mid-game support: offers option to immediately update player life or only set template for future resets.
class StartingLifeTemplatesSheet extends StatefulWidget {
  final int currentStartingLife;
  final String currentFormat;
  final int playerCount;
  final bool isMidGame;
  final void Function(int newStartingLife, String format, bool updateCurrentLife)? onApply;

  const StartingLifeTemplatesSheet({
    super.key,
    this.currentStartingLife = 40,
    this.currentFormat = 'commander',
    this.playerCount = 4,
    this.isMidGame = false,
    this.onApply,
  });

  /// Displays the [StartingLifeTemplatesSheet] bottom sheet.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    int currentStartingLife = 40,
    String currentFormat = 'commander',
    int playerCount = 4,
    bool isMidGame = false,
    void Function(int newStartingLife, String format, bool updateCurrentLife)? onApply,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StartingLifeTemplatesSheet(
          currentStartingLife: currentStartingLife,
          currentFormat: currentFormat,
          playerCount: playerCount,
          isMidGame: isMidGame,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  State<StartingLifeTemplatesSheet> createState() => _StartingLifeTemplatesSheetState();
}

class _StartingLifeTemplatesSheetState extends State<StartingLifeTemplatesSheet> {
  late int _selectedLife;
  late String _selectedFormat;
  late bool _updateCurrentLife;
  late final TextEditingController _customController;
  final _formKey = GlobalKey<FormState>();

  static const Map<String, int> _presets = {
    'standard': 20,
    'brawl': 30,
    'commander': 40,
  };

  @override
  void initState() {
    super.initState();
    _selectedLife = widget.currentStartingLife.clamp(1, 999);
    _selectedFormat = widget.currentFormat.toLowerCase();
    _updateCurrentLife = widget.isMidGame;
    _customController = TextEditingController(text: '$_selectedLife');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _setLife(int life, {String? format}) {
    final clamped = life.clamp(1, 999);
    setState(() {
      _selectedLife = clamped;
      _customController.text = '$clamped';
      if (format != null) {
        _selectedFormat = format;
      } else {
        // Detect if matching known preset
        final matching = _presets.entries
            .where((entry) => entry.value == clamped)
            .map((entry) => entry.key)
            .firstOrNull;
        _selectedFormat = matching ?? 'custom';
      }
    });
  }

  void _handleCustomSubmitted(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 1 && parsed <= 999) {
      _setLife(parsed);
    }
  }

  void _applySelection() {
    widget.onApply?.call(_selectedLife, _selectedFormat, _updateCurrentLife);
    Navigator.of(context).pop({
      'startingLife': _selectedLife,
      'format': _selectedFormat,
      'updateCurrentLife': _updateCurrentLife,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('starting_life_templates_sheet'),
      decoration: const BoxDecoration(
        color: Color(0xFF141820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Starting Life Templates',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  key: const Key('cancel_starting_life_btn'),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select an official MTG format preset or define a custom starting life total.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Format Preset Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('Standard (20)', 'standard', 20),
                _buildPresetChip('Brawl (30)', 'brawl', 30),
                _buildPresetChip('Commander (40)', 'commander', 40),
                _buildCustomChip('Custom', 'custom'),
              ],
            ),
            const SizedBox(height: 16),

            // Stepper & Direct Input Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C222C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Starting Life:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('life_dec_btn'),
                        icon: const Icon(Icons.remove_circle, color: AppColors.accentGold, size: 28),
                        onPressed: () => _setLife(_selectedLife - 5),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 72,
                        child: Form(
                          key: _formKey,
                          child: TextFormField(
                            key: const Key('custom_life_input'),
                            controller: _customController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _handleCustomSubmitted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const Key('life_inc_btn'),
                        icon: const Icon(Icons.add_circle, color: AppColors.accentGold, size: 28),
                        onPressed: () => _setLife(_selectedLife + 5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Starting life text indicator for exact test matchers
            Center(
              child: Text(
                'Selected: $_selectedLife Life',
                key: const Key('starting_life_value_text'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Mid-game apply option
            if (widget.isMidGame) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x33FF9E40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      key: const Key('update_current_life_toggle'),
                      value: _updateCurrentLife,
                      activeColor: AppColors.accentGold,
                      onChanged: (val) => setState(() => _updateCurrentLife = val ?? true),
                    ),
                    const Expanded(
                      child: Text(
                        'Apply to current game (resets active life totals to this template).',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Apply Action Button
            ElevatedButton(
              key: const Key('apply_starting_life_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _applySelection,
              child: const Text(
                'Apply Starting Life',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String formatKey, int life) {
    final isSelected = _selectedLife == life && _selectedFormat == formatKey;
    return ChoiceChip(
      key: Key('preset_chip_$formatKey'),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _setLife(life, format: formatKey);
        }
      },
      selectedColor: AppColors.accentGold,
      backgroundColor: const Color(0xFF1C222C),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accentGold : Colors.white12,
      ),
    );
  }

  Widget _buildCustomChip(String label, String formatKey) {
    final isSelected = _selectedFormat == 'custom' || !_presets.containsValue(_selectedLife);
    return ChoiceChip(
      key: Key('preset_chip_$formatKey'),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFormat = 'custom';
          });
        }
      },
      selectedColor: AppColors.accentGold,
      backgroundColor: const Color(0xFF1C222C),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accentGold : Colors.white12,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/deck_token_extractor.dart';
import 'package:countr/features/decks/presentation/providers/deck_gear_providers.dart';

class DeckGearSection extends ConsumerStatefulWidget {
  final String deckId;
  final Deck? deck;
  final List<VaultItem>? deckItems;

  const DeckGearSection({
    super.key,
    required this.deckId,
    this.deck,
    this.deckItems,
  });

  @override
  ConsumerState<DeckGearSection> createState() => _DeckGearSectionState();
}

class _DeckGearSectionState extends ConsumerState<DeckGearSection> {
  late TextEditingController _sleeveBrandCtrl;
  late TextEditingController _sleeveColorCtrl;
  late TextEditingController _deckBoxCtrl;

  @override
  void initState() {
    super.initState();
    final gear = ref.read(deckGearProvider(widget.deckId));
    _sleeveBrandCtrl = TextEditingController(text: gear.sleeveBrand);
    _sleeveColorCtrl = TextEditingController(text: gear.sleeveColor);
    _deckBoxCtrl = TextEditingController(text: gear.deckBoxModel);
  }

  @override
  void dispose() {
    _sleeveBrandCtrl.dispose();
    _sleeveColorCtrl.dispose();
    _deckBoxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(deckGearProvider(widget.deckId));
    final checkedTokens = ref.watch(deckCheckedTokensProvider(widget.deckId));

    // Extract Oracle texts from deck cards
    final oracleTexts = <String>[];
    if (widget.deckItems != null && widget.deckItems!.isNotEmpty) {
      for (final item in widget.deckItems!) {
        oracleTexts.addAll(DeckTokenExtractor.extractOracleTextsFromCardData(item.dynamicData));
      }
    }

    final requiredTokens = DeckTokenExtractor.extractRequiredTokens(oracleTexts);

    return Container(
      key: const Key('deck_gear_section'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: const [
              Icon(Icons.shield_outlined, color: AppColors.accentCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'Deck Gear & Physical Checklist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Sleeve Profile
          const Text(
            'Sleeve Profile',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('deck_gear_sleeve_brand_input'),
                  controller: _sleeveBrandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    hintText: 'e.g. Dragon Shield',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    ref.read(deckGearProvider(widget.deckId).notifier).setSleeveBrand(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('deck_gear_sleeve_color_input'),
                  controller: _sleeveColorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    hintText: 'e.g. Matte Slate',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    ref.read(deckGearProvider(widget.deckId).notifier).setSleeveColor(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Deck Box Model
          const Text(
            'Deck Box Model',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('deck_gear_box_model_input'),
            controller: _deckBoxCtrl,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'e.g. Ultimate Guard Boulder 100+',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              ref.read(deckGearProvider(widget.deckId).notifier).setDeckBoxModel(val);
            },
          ),
          const SizedBox(height: 20),

          // 3. Auto-Generated Physical Token Checklist
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Token Checklist (${requiredTokens.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentCyan,
                ),
              ),
              if (requiredTokens.isNotEmpty)
                Text(
                  '${checkedTokens.length}/${requiredTokens.length} Packed',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (requiredTokens.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tokens required for this deck.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requiredTokens.length,
              itemBuilder: (context, idx) {
                final token = requiredTokens[idx];
                final isChecked = checkedTokens.contains(token);

                return CheckboxListTile(
                  key: Key('token_checklist_item_$token'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    token,
                    style: TextStyle(
                      fontSize: 14,
                      color: isChecked ? AppColors.textMuted : Colors.white,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: isChecked,
                  activeColor: AppColors.accentCyan,
                  onChanged: (_) {
                    ref.read(deckCheckedTokensProvider(widget.deckId).notifier).toggle(token);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

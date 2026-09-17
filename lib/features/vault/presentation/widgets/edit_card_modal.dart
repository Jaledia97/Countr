import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Modal bottom sheet allowing comprehensive edits to a Vault card's
/// printing variant, custom tags, acquired price, and condition checkboxes.
class EditCardModal extends ConsumerStatefulWidget {
  final VaultItem item;
  final void Function(VaultItem updatedItem)? onSaved;

  const EditCardModal({super.key, required this.item, this.onSaved});

  /// Opens the [EditCardModal] in a bottom sheet and returns the updated [VaultItem].
  static Future<VaultItem?> show(BuildContext context, VaultItem item) {
    return showModalBottomSheet<VaultItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => EditCardModal(item: item),
    );
  }

  @override
  ConsumerState<EditCardModal> createState() => _EditCardModalState();
}

class _EditCardModalState extends ConsumerState<EditCardModal> {
  late TextEditingController _priceController;
  late TextEditingController _tagInputController;
  late String _selectedCondition;
  late bool _isGraded;
  late bool _isAltered;
  late bool _isMisprint;
  late bool _isSigned;
  late String _selectedVariant;
  late List<String> _tags;
  bool _isSaving = false;

  static const _conditionGrades = ['NM', 'LP', 'MP', 'HP', 'DMG'];

  static const _variants = [
    'Standard',
    'Foil / Holographic',
    'Extended Art',
    'Showcase / Borderless',
    'Retro Frame',
  ];

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.acquiredPrice.toStringAsFixed(2),
    );
    _tagInputController = TextEditingController();

    _selectedCondition = _conditionGrades.contains(widget.item.condition)
        ? widget.item.condition
        : 'NM';

    _isGraded = widget.item.isGraded;
    _isAltered = widget.item.isAltered;
    _isMisprint = widget.item.isMisprint;
    _isSigned = widget.item.isSigned;

    _selectedVariant = 'Standard';
    for (final v in _variants) {
      if (widget.item.setOrSeries.contains('($v)')) {
        _selectedVariant = v;
        break;
      }
    }

    _tags = [];
    if (widget.item.dynamicData.isNotEmpty) {
      try {
        final data = jsonDecode(widget.item.dynamicData) as Map<String, dynamic>;
        final rawTags = data['tags'] ?? data['deck_history'];
        if (rawTags is List) {
          _tags = rawTags.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagInputController.clear();
      });
    }
  }

  Future<void> _saveEdits() async {
    setState(() => _isSaving = true);
    final dao = ref.read(vaultDaoProvider);
    final parsedPrice = double.tryParse(_priceController.text) ?? widget.item.acquiredPrice;

    String setOrSeries = widget.item.setOrSeries;
    for (final v in _variants) {
      setOrSeries = setOrSeries.replaceAll(' ($v)', '');
    }
    if (_selectedVariant != 'Standard') {
      setOrSeries = '$setOrSeries ($_selectedVariant)';
    }

    await dao.updateItemCardDetails(
      id: widget.item.id,
      acquiredPrice: parsedPrice,
      condition: _selectedCondition,
      isGraded: _isGraded,
      isAltered: _isAltered,
      isMisprint: _isMisprint,
      isSigned: _isSigned,
      setOrSeries: setOrSeries,
      tags: _tags,
    );

    final updated = await dao.getItemById(widget.item.id);
    final fallbackItem = widget.item.copyWith(
      acquiredPrice: parsedPrice,
      condition: _selectedCondition,
      isGraded: _isGraded,
      isAltered: _isAltered,
      isMisprint: _isMisprint,
      isSigned: _isSigned,
      setOrSeries: setOrSeries,
    );

    final finalItem = updated ?? fallbackItem;
    widget.onSaved?.call(finalItem);

    if (mounted) {
      Navigator.of(context).pop(finalItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Card Details',
                            style: AppTypography.heading1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.name,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

              // Form content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  children: [
                    // Section: Variant / Printing Selector
                    _buildSectionTitle('Variant / Printing Treatment'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const Key('edit_card_variant_selector'),
                      isExpanded: true,
                      initialValue: _selectedVariant,
                      dropdownColor: AppColors.surfaceRaised,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _variants.map((v) {
                        return DropdownMenuItem<String>(
                          value: v,
                          child: Text(
                            v,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedVariant = val);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Section: Acquired Price Numeric Override
                    _buildSectionTitle('Acquired Price Override'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('edit_card_acquired_price_field'),
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 8, top: 13),
                          child: Text('\$', style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        hintText: '0.00',
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section: Condition Grade Dropdown
                    _buildSectionTitle('Condition Grade'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const Key('condition_grade_dropdown'),
                      isExpanded: true,
                      initialValue: _selectedCondition,
                      dropdownColor: AppColors.surfaceRaised,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'NM',
                          child: Text(
                            'NM — Near Mint',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'LP',
                          child: Text(
                            'LP — Lightly Played',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'MP',
                          child: Text(
                            'MP — Moderately Played',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'HP',
                          child: Text(
                            'HP — Heavily Played',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'DMG',
                          child: Text(
                            'DMG — Damaged',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCondition = val);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Section: Schema v4 Condition Flags
                    _buildSectionTitle('Condition Flags & Authentications'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  key: const Key('condition_checkbox_graded'),
                                  dense: true,
                                  title: const Text('Graded', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  value: _isGraded,
                                  onChanged: (val) => setState(() => _isGraded = val ?? false),
                                  activeColor: AppColors.accentCyan,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  key: const Key('condition_checkbox_altered'),
                                  dense: true,
                                  title: const Text('Altered', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  value: _isAltered,
                                  onChanged: (val) => setState(() => _isAltered = val ?? false),
                                  activeColor: AppColors.accentCyan,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  key: const Key('condition_checkbox_misprint'),
                                  dense: true,
                                  title: const Text('Misprint', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  value: _isMisprint,
                                  onChanged: (val) => setState(() => _isMisprint = val ?? false),
                                  activeColor: AppColors.accentCyan,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  key: const Key('condition_checkbox_signed'),
                                  dense: true,
                                  title: const Text('Signed', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  value: _isSigned,
                                  onChanged: (val) => setState(() => _isSigned = val ?? false),
                                  activeColor: AppColors.accentCyan,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section: Custom Tag Editor
                    _buildSectionTitle('Custom Tags'),
                    const SizedBox(height: 8),
                    if (_tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _tags.map((tag) {
                            return Chip(
                              key: Key('tag_chip_$tag'),
                              label: Text(tag, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              backgroundColor: AppColors.surfaceRaised,
                              deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.accentRose),
                              side: const BorderSide(color: AppColors.surfaceBorder),
                              onDeleted: () {
                                setState(() => _tags.remove(tag));
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('edit_card_tag_input'),
                            controller: _tagInputController,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add custom tag (e.g., Foil, Commander)...',
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              filled: true,
                              fillColor: AppColors.surfaceRaised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.surfaceBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.surfaceBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('edit_card_add_tag_button'),
                          icon: const Icon(Icons.add_circle, color: AppColors.accentCyan, size: 28),
                          onPressed: _addTag,
                        ),
                      ],
                    ),

                  ],
                ),
              ),

              // Pinned Save Button
              const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).viewInsets.bottom + 12
                      : 20,
                ),
                color: AppColors.surface,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('save_card_edits_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.textDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isSaving ? null : _saveEdits,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDark),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.accentCyan,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

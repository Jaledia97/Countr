import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';

/// Modal bottom sheet allowing comprehensive edits to a Vault card's
/// printing variant, custom tags, acquired price, physical provenance,
/// acquisition data, and condition checkboxes.
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
  late TextEditingController _purchasePriceController;
  late TextEditingController _binderPageController;
  late TextEditingController _binderSlotController;
  late TextEditingController _notesController;
  late TextEditingController _tagInputController;
  late String _selectedCondition;
  late String _selectedProtectionStatus;
  DateTime? _dateObtained;
  late bool _isGraded;
  late bool _isAltered;
  late bool _isMisprint;
  late bool _isSigned;
  late String _selectedVariant;
  late List<String> _tags;
  bool _isSaving = false;

  static const _conditionGrades = ['NM', 'LP', 'MP', 'HP', 'DMG'];

  static const _protectionStatuses = [
    'Sleeved',
    'Double Sleeved',
    'Perfect Fit',
    'Penny Sleeve',
    'Toploader',
    'Magnetic One-Touch',
    'Graded Slab',
    'Raw',
  ];

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
    final initialAcquired = widget.item.acquiredPrice;
    final initialPurchase = widget.item.purchasePrice ?? initialAcquired;

    _priceController = TextEditingController(
      text: initialAcquired > 0 ? initialAcquired.toStringAsFixed(2) : '',
    );
    _purchasePriceController = TextEditingController(
      text: initialPurchase > 0 ? initialPurchase.toStringAsFixed(2) : '',
    );
    _binderPageController = TextEditingController(
      text: widget.item.binderPage != null ? widget.item.binderPage.toString() : '',
    );
    _binderSlotController = TextEditingController(
      text: widget.item.binderSlot ?? '',
    );
    _notesController = TextEditingController(
      text: widget.item.notes ?? widget.item.personalNotes ?? '',
    );
    _tagInputController = TextEditingController();

    _selectedCondition = _conditionGrades.contains(widget.item.condition)
        ? widget.item.condition
        : 'NM';

    _selectedProtectionStatus = _protectionStatuses.contains(widget.item.protectionStatus)
        ? widget.item.protectionStatus!
        : 'Sleeved';

    _dateObtained = widget.item.dateObtained ?? widget.item.acquiredDate;

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
      } catch (e, stackTrace) {
        debugPrint('[EditCardModal] Failed to parse tags from dynamicData: $e\n$stackTrace');
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _purchasePriceController.dispose();
    _binderPageController.dispose();
    _binderSlotController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickDateObtained() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateObtained ?? now,
      firstDate: DateTime(1990),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dateObtained = picked);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
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
    try {
      double parsedPrice = double.tryParse(_priceController.text) ?? widget.item.acquiredPrice;
      double parsedPurchasePrice = double.tryParse(_purchasePriceController.text) ?? parsedPrice;

      final initialAcquiredStr = widget.item.acquiredPrice > 0 ? widget.item.acquiredPrice.toStringAsFixed(2) : '';
      final initialPurchaseStr = (widget.item.purchasePrice ?? widget.item.acquiredPrice) > 0
          ? (widget.item.purchasePrice ?? widget.item.acquiredPrice).toStringAsFixed(2)
          : '';

      final priceChanged = _priceController.text.trim() != initialAcquiredStr;
      final purchaseChanged = _purchasePriceController.text.trim() != initialPurchaseStr;

      if (priceChanged && !purchaseChanged) {
        parsedPurchasePrice = parsedPrice;
      } else if (purchaseChanged && !priceChanged) {
        parsedPrice = parsedPurchasePrice;
      }

      final parsedBinderPage = int.tryParse(_binderPageController.text.trim());
      final binderSlot = _binderSlotController.text.trim();
      final notes = _notesController.text.trim();

      String setOrSeries = widget.item.setOrSeries;
      for (final v in _variants) {
        setOrSeries = setOrSeries.replaceAll(' ($v)', '');
      }
      if (_selectedVariant != 'Standard') {
        setOrSeries = '$setOrSeries ($_selectedVariant)';
      }

      final dao = ref.read(vaultDaoProvider);
      await dao.updateItemCardDetails(
        id: widget.item.id,
        acquiredPrice: parsedPrice,
        purchasePrice: parsedPurchasePrice,
        dateObtained: _dateObtained,
        binderPage: parsedBinderPage,
        binderSlot: binderSlot.isNotEmpty ? binderSlot : null,
        notes: notes.isNotEmpty ? notes : null,
        personalNotes: notes.isNotEmpty ? notes : null,
        protectionStatus: _selectedProtectionStatus,
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
        purchasePrice: Value(parsedPurchasePrice),
        dateObtained: Value(_dateObtained),
        binderPage: Value(parsedBinderPage),
        binderSlot: Value(binderSlot.isNotEmpty ? binderSlot : null),
        notes: Value(notes.isNotEmpty ? notes : null),
        personalNotes: Value(notes.isNotEmpty ? notes : null),
        protectionStatus: Value(_selectedProtectionStatus),
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
    } catch (e, stackTrace) {
      debugPrint('[EditCardModal] Failed to save edits: $e\n$stackTrace');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving card: $e')),
        );
      }
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Section: Variant / Printing Selector
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildSectionTitle('Variant / Printing Treatment'),
                        TextButton.icon(
                          key: const Key('open_switch_printing_modal_button'),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.accentCyan),
                          label: const Text('Switch Printing', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final updated = await SwitchPrintingModal.show(context, widget.item);
                            if (updated != null && mounted) {
                              setState(() {
                                _selectedVariant = updated.setOrSeries;
                              });
                              widget.onSaved?.call(updated);
                            }
                          },
                        ),
                      ],
                    ),
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

                    // Section: Acquisition Tracking
                    _buildSectionTitle('Acquisition Tracking'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('edit_card_date_obtained_button'),
                            icon: const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.accentCyan),
                            label: Text(
                              'Date Obtained: ${_dateObtained != null ? _formatDate(_dateObtained!) : "Not set"}',
                              style: const TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              side: const BorderSide(color: AppColors.accentCyan),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: _pickDateObtained,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Purchase Price',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            key: const Key('edit_card_purchase_price_input'),
                            controller: _purchasePriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 14, right: 8, top: 13),
                                child: Text('\$', style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              hintText: '0.00',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.surfaceBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section: Physical Provenance
                    _buildSectionTitle('Physical Provenance'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Protection Status',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const Key('edit_card_protection_status_dropdown'),
                            isExpanded: true,
                            initialValue: _selectedProtectionStatus,
                            dropdownColor: AppColors.surfaceRaised,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.surfaceBorder),
                              ),
                            ),
                            items: _protectionStatuses.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedProtectionStatus = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Binder Page',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      key: const Key('edit_card_binder_page_input'),
                                      controller: _binderPageController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Page #',
                                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Binder Slot',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      key: const Key('edit_card_binder_slot_input'),
                                      controller: _binderSlotController,
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Slot (e.g. A3)',
                                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Personal Notes & Strategy Tips',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            key: const Key('edit_card_notes_input'),
                            controller: _notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Enter combos, strategy tips, or personal notes...',
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.surfaceBorder),
                              ),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ],
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
                  key: const Key('edit_card_save_button'),
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

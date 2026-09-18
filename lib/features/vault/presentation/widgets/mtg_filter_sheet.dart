import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

/// ManaBox-style modal bottom sheet filter screen for Magic: The Gathering.
/// Provides dual-tab navigation ([ General ] and [ Collection ]) covering all Scryfall filter dimensions.
class MtgFilterSheet extends StatefulWidget {
  final MtgFilterState? initialState;
  final ValueChanged<MtgFilterState>? onApply;
  final VoidCallback? onReset;
  final List<VaultItem>? items;

  const MtgFilterSheet({
    super.key,
    this.initialState,
    this.onApply,
    this.onReset,
    this.items,
  });

  /// Opens the MtgFilterSheet inside a high-performance scroll-controlled modal sheet.
  static Future<MtgFilterState?> show(
    BuildContext context, {
    MtgFilterState? initialState,
    ValueChanged<MtgFilterState>? onApply,
    VoidCallback? onReset,
    List<VaultItem>? items,
  }) {
    // If running with ProviderScope, grab current provider state if initialState not given
    MtgFilterState? resolvedInitial = initialState;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      resolvedInitial ??= container.read(mtgFilterProvider);
    } catch (_) {}

    return showModalBottomSheet<MtgFilterState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => MtgFilterSheet(
        initialState: resolvedInitial ?? const MtgFilterState(),
        onApply: onApply,
        onReset: onReset,
        items: items,
      ),
    );
  }

  @override
  State<MtgFilterSheet> createState() => _MtgFilterSheetState();
}

class _MtgFilterSheetState extends State<MtgFilterSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MtgFilterState _state;
  bool _initializedFromProvider = false;

  // Form Controllers
  late TextEditingController _typeLineController;
  late TextEditingController _oracleClauseController;
  late TextEditingController _manaCostController;
  late TextEditingController _setCodeController;
  late TextEditingController _statValueController;

  String _selectedStatType = 'power';
  String _selectedStatOp = '=';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _state = widget.initialState ?? const MtgFilterState();

    _typeLineController = TextEditingController(text: _state.typeLine);
    _oracleClauseController = TextEditingController();
    _manaCostController = TextEditingController(text: _state.manaCost);
    _setCodeController = TextEditingController(text: _state.setCode);
    _statValueController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromProvider && widget.initialState == null) {
      _initializedFromProvider = true;
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final providerState = container.read(mtgFilterProvider);
        if (mounted) {
          setState(() {
            _state = providerState;
            _typeLineController.text = _state.typeLine;
            _manaCostController.text = _state.manaCost;
            _setCodeController.text = _state.setCode;
          });
        }
      } catch (_) {
        // Fallback for standalone unit/widget tests without ProviderScope
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _typeLineController.dispose();
    _oracleClauseController.dispose();
    _manaCostController.dispose();
    _setCodeController.dispose();
    _statValueController.dispose();
    super.dispose();
  }

  void _handleReset() {
    setState(() {
      _state = const MtgFilterState();
      _typeLineController.clear();
      _oracleClauseController.clear();
      _manaCostController.clear();
      _setCodeController.clear();
      _statValueController.clear();
    });
    widget.onReset?.call();
    _syncWithProviderIfAvailable(const MtgFilterState());
  }

  void _handleApply() {
    // Sync active text fields into state
    final applied = _state.copyWith(
      typeLine: _typeLineController.text.trim(),
      manaCost: _manaCostController.text.trim(),
      setCode: _setCodeController.text.trim(),
    );

    _syncWithProviderIfAvailable(applied);
    widget.onApply?.call(applied);
    Navigator.of(context).maybePop(applied);
  }

  void _syncWithProviderIfAvailable(MtgFilterState updated) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(mtgFilterProvider.notifier).setFilter(updated);
    } catch (_) {
      // Safe fallback when running in standalone unit/widget tests
    }
  }

  int? _calculateMatchingItems() {
    if (widget.items == null || widget.items!.isEmpty) return null;
    return widget.items!.where((i) => _state.matches(i)).length;
  }

  @override
  Widget build(BuildContext context) {
    final matchingCount = _calculateMatchingItems();

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
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
            // Top Drag Handle
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

            // Header Bar with Title, Active Count Badge, Reset All & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          flex: 3,
                          fit: FlexFit.loose,
                          child: const Text(
                            'Filter Cards',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (_state.isActive) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            fit: FlexFit.loose,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${_state.activeCount} active',
                                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                                  style: const TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('mtg_filter_reset_button'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _handleReset,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Reset',
                        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                        style: const TextStyle(
                          color: AppColors.accentRose,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('mtg_filter_close_button'),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    tooltip: 'Close Filters',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),

            // Navigation Tabs: [ General ] and [ Collection ]
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceBorder, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accentCyan,
                indicatorWeight: 3,
                labelColor: AppColors.accentCyan,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(key: Key('mtg_filter_tab_general'), text: 'General'),
                  Tab(key: Key('mtg_filter_tab_collection'), text: 'Collection'),
                ],
              ),
            ),

            // Tab Content Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildCollectionTab(),
                ],
              ),
            ),

            // Sticky Bottom Action Bar
            _buildStickyActionBar(matchingCount),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // GENERAL TAB
  // ===========================================================================

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Colors & Identity
        _buildSectionHeader('Colors & Identity'),
        const SizedBox(height: 8),

        // Color Match Mode
        const Text('Match Mode', style: AppTypography.caption),
        const SizedBox(height: 6),
        SegmentedButton<ColorMatchMode>(
          key: const Key('filter_color_match_mode_selector'),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.surfaceRaised,
            selectedBackgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
            selectedForegroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.textSecondary,
          ),
          segments: const [
            ButtonSegment(value: ColorMatchMode.including, label: Text('Including')),
            ButtonSegment(value: ColorMatchMode.exactly, label: Text('Exactly')),
            ButtonSegment(value: ColorMatchMode.atMost, label: Text('At most')),
            ButtonSegment(value: ColorMatchMode.commander, label: Text('Commander')),
          ],
          selected: {_state.colorMatchMode},
          onSelectionChanged: (newSelection) {
            setState(() {
              _state = _state.copyWith(colorMatchMode: newSelection.first);
            });
          },
        ),
        const SizedBox(height: 12),

        // WUBRGC Circular Mana Buttons
        const Text('Mana Colors', style: AppTypography.caption),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCircularManaButton('W', 'White', const Color(0xFFFFFDE7), Colors.black87),
            _buildCircularManaButton('U', 'Blue', const Color(0xFF0E68AB), Colors.white),
            _buildCircularManaButton('B', 'Black', const Color(0xFF211E1D), Colors.white),
            _buildCircularManaButton('R', 'Red', const Color(0xFFD3202A), Colors.white),
            _buildCircularManaButton('G', 'Green', const Color(0xFF00733E), Colors.white),
            _buildCircularManaButton('C', 'Colorless', const Color(0xFF9E9895), Colors.white),
          ],
        ),
        const SizedBox(height: 12),

        // Mana Value (CMC) Range
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Mana Value (CMC) Range',
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_state.cmcRange.start.toInt()} to ${_state.cmcRange.end.toInt() >= 16 ? '16+' : _state.cmcRange.end.toInt().toString()}',
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        RangeSlider(
          key: const Key('filter_cmc_slider'),
          activeColor: AppColors.accentCyan,
          inactiveColor: AppColors.surfaceBorder,
          values: _state.cmcRange,
          min: 0,
          max: 16,
          divisions: 16,
          labels: RangeLabels(
            '${_state.cmcRange.start.toInt()}',
            '${_state.cmcRange.end.toInt() >= 16 ? '16+' : _state.cmcRange.end.toInt()}',
          ),
          onChanged: (values) {
            setState(() {
              _state = _state.copyWith(cmcRange: values);
            });
          },
        ),
        const SizedBox(height: 12),

        // Color Target Toggle: Card Color vs Color Identity
        const Text('Target', style: AppTypography.caption),
        const SizedBox(height: 6),
        SegmentedButton<ColorTarget>(
          key: const Key('filter_color_target_selector'),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.surfaceRaised,
            selectedBackgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
            selectedForegroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.textSecondary,
          ),
          segments: const [
            ButtonSegment(value: ColorTarget.cardColor, label: Text('Card Color')),
            ButtonSegment(value: ColorTarget.colorIdentity, label: Text('Color Identity')),
          ],
          selected: {_state.colorTarget},
          onSelectionChanged: (newSelection) {
            setState(() {
              _state = _state.copyWith(colorTarget: newSelection.first);
            });
          },
        ),
        const SizedBox(height: 12),

        // Number of Colors Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Number of Colors', style: AppTypography.caption),
            Text(
              '${_state.colorCountRange.start.toInt()} to ${_state.colorCountRange.end.toInt()}',
              style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
        RangeSlider(
          key: const Key('filter_color_count_slider'),
          activeColor: AppColors.accentCyan,
          inactiveColor: AppColors.surfaceBorder,
          values: _state.colorCountRange,
          min: 0,
          max: 5,
          divisions: 5,
          labels: RangeLabels(
            '${_state.colorCountRange.start.toInt()}',
            '${_state.colorCountRange.end.toInt()}',
          ),
          onChanged: (values) {
            setState(() {
              _state = _state.copyWith(colorCountRange: values);
            });
          },
        ),
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 2. Mana Cost & Mana Value (CMC)
        _buildSectionHeader('Mana Cost'),
        const SizedBox(height: 8),

        _buildTextField(
          key: const Key('filter_mana_cost_field'),
          controller: _manaCostController,
          label: 'Exact Mana Cost',
          hintText: 'e.g. {2}{W}{U}',
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(manaCost: val.trim());
            });
          },
        ),
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 3. Card Types & Oracle Text
        _buildSectionHeader('Card Types & Oracle Text'),
        const SizedBox(height: 8),

        // Type Line Field
        _buildTextField(
          key: const Key('filter_type_line_field'),
          controller: _typeLineController,
          label: 'Type Line',
          hintText: 'e.g. Creature, Legendary Artifact, Elf',
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(typeLine: val.trim());
            });
          },
        ),
        const SizedBox(height: 12),

        // Oracle Text Dynamic Clauses
        const Text('Oracle Text Clauses', style: AppTypography.caption),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                key: const Key('filter_oracle_clause_field'),
                controller: _oracleClauseController,
                hintText: 'e.g. draw a card, flying, sacrifice',
                onSubmitted: (_) => _addOracleClause(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              key: const Key('filter_add_oracle_clause_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceRaised,
                foregroundColor: AppColors.accentCyan,
                side: const BorderSide(color: AppColors.surfaceBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: _addOracleClause,
            ),
          ],
        ),
        if (_state.oracleTextClauses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _state.oracleTextClauses.asMap().entries.map((entry) {
              final idx = entry.key;
              final clause = entry.value;
              return Chip(
                key: Key('filter_oracle_chip_$idx'),
                backgroundColor: AppColors.surfaceRaised,
                label: Text('"$clause"', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                onDeleted: () {
                  final list = List<String>.from(_state.oracleTextClauses)..removeAt(idx);
                  setState(() {
                    _state = _state.copyWith(oracleTextClauses: list);
                  });
                },
              );
            }).toList(),
          ),
        ],
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 4. Sets & Rarity
        _buildSectionHeader('Sets & Rarity'),
        const SizedBox(height: 8),

        Row(
          children: [
            SizedBox(
              width: 96,
              child: SegmentedButton<String>(
                key: const Key('filter_set_operator_toggle'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  selectedBackgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
                  selectedForegroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                ),
                segments: const [
                  ButtonSegment(value: '=', label: Text('=')),
                  ButtonSegment(value: '!=', label: Text('!=')),
                ],
                selected: {_state.setOperator},
                onSelectionChanged: (sel) {
                  setState(() {
                    _state = _state.copyWith(setOperator: sel.first);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(
                key: const Key('filter_set_code_field'),
                controller: _setCodeController,
                hintText: 'Set code (e.g. MH3, OTJ, SLD)',
                onChanged: (val) {
                  setState(() {
                    _state = _state.copyWith(setCode: val.trim());
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Text('Rarity', style: AppTypography.caption),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['common', 'uncommon', 'rare', 'mythic', 'special', 'bonus'].map((r) {
            final isSelected = _state.rarities.contains(r);
            return FilterChip(
              key: Key('filter_chip_rarity_$r'),
              label: Text(r[0].toUpperCase() + r.substring(1)),
              selected: isSelected,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
              checkmarkColor: AppColors.accentCyan,
              backgroundColor: AppColors.surfaceRaised,
              onSelected: (selected) {
                final set = Set<String>.from(_state.rarities);
                if (selected) {
                  set.add(r);
                } else {
                  set.remove(r);
                }
                setState(() {
                  _state = _state.copyWith(rarities: set);
                });
              },
            );
          }).toList(),
        ),
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 5. Stats (Power, Toughness, Loyalty, Defense)
        _buildSectionHeader('Stats (P/T / Loyalty / Defense)'),
        const SizedBox(height: 8),

        Row(
          children: [
            DropdownButton<String>(
              key: const Key('filter_stat_type_dropdown'),
              value: _selectedStatType,
              dropdownColor: AppColors.surfaceRaised,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 'power', child: Text('Power')),
                DropdownMenuItem(value: 'toughness', child: Text('Toughness')),
                DropdownMenuItem(value: 'loyalty', child: Text('Loyalty')),
                DropdownMenuItem(value: 'defense', child: Text('Defense')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatType = v);
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              key: const Key('filter_stat_operator_dropdown'),
              value: _selectedStatOp,
              dropdownColor: AppColors.surfaceRaised,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: const [
                DropdownMenuItem(value: '=', child: Text('=')),
                DropdownMenuItem(value: '>', child: Text('>')),
                DropdownMenuItem(value: '<', child: Text('<')),
                DropdownMenuItem(value: '>=', child: Text('>=')),
                DropdownMenuItem(value: '<=', child: Text('<=')),
                DropdownMenuItem(value: '!=', child: Text('!=')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatOp = v);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(
                key: const Key('filter_stat_value_field'),
                controller: _statValueController,
                hintText: 'Value (e.g. 3, *)',
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              key: const Key('filter_add_stat_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceRaised,
                foregroundColor: AppColors.accentCyan,
                side: const BorderSide(color: AppColors.surfaceBorder),
              ),
              onPressed: _addStatFilter,
              child: const Text('Add'),
            ),
          ],
        ),
        if (_state.statFilters.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _state.statFilters.asMap().entries.map((entry) {
              final idx = entry.key;
              final sf = entry.value;
              return Chip(
                key: Key('filter_stat_chip_$idx'),
                backgroundColor: AppColors.surfaceRaised,
                label: Text(sf.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                onDeleted: () {
                  final list = List<MtgStatFilter>.from(_state.statFilters)..removeAt(idx);
                  setState(() {
                    _state = _state.copyWith(statFilters: list);
                  });
                },
              );
            }).toList(),
          ),
        ],
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 6. Layouts
        _buildSectionHeader('Card Layouts'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'normal',
            'split',
            'flip',
            'transform',
            'modal_dfc',
            'adventure',
            'meld',
            'leveler',
          ].map((layout) {
            final isSelected = _state.layouts.contains(layout);
            final displayLabel = _formatLayoutLabel(layout);
            return FilterChip(
              key: Key('filter_chip_layout_$layout'),
              label: Text(displayLabel),
              selected: isSelected,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
              checkmarkColor: AppColors.accentCyan,
              backgroundColor: AppColors.surfaceRaised,
              onSelected: (selected) {
                final set = Set<String>.from(_state.layouts);
                if (selected) {
                  set.add(layout);
                } else {
                  set.remove(layout);
                }
                setState(() {
                  _state = _state.copyWith(layouts: set);
                });
              },
            );
          }).toList(),
        ),
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 7. Treatments & Finishes
        _buildSectionHeader('Treatments & Finishes'),
        const SizedBox(height: 8),

        CheckboxListTile(
          key: const Key('filter_checkbox_universes_beyond'),
          title: const Text('Universes Beyond', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _state.isUniversesBeyond ?? false,
          activeColor: AppColors.accentCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isUniversesBeyond: () => val == true ? true : null);
            });
          },
        ),
        CheckboxListTile(
          key: const Key('filter_checkbox_reserved'),
          title: const Text('Reserved List Only', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _state.isReserved ?? false,
          activeColor: AppColors.accentCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isReserved: () => val == true ? true : null);
            });
          },
        ),
        CheckboxListTile(
          key: const Key('filter_checkbox_promo'),
          title: const Text('Promotional Printings', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _state.isPromo ?? false,
          activeColor: AppColors.accentCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isPromo: () => val == true ? true : null);
            });
          },
        ),
        CheckboxListTile(
          key: const Key('filter_checkbox_reprint'),
          title: const Text('Reprints', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _state.isReprint ?? false,
          activeColor: AppColors.accentCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isReprint: () => val == true ? true : null);
            });
          },
        ),
        CheckboxListTile(
          key: const Key('filter_checkbox_altered'),
          title: const Text('Altered Cards', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _state.isAltered ?? false,
          activeColor: AppColors.accentCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isAltered: () => val == true ? true : null);
            });
          },
        ),
        CheckboxListTile(
          key: const Key('filter_checkbox_misprint'),
          title: const Text('Misprints / Errors', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _state.isMisprint ?? false,
          activeColor: AppColors.accentCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isMisprint: () => val == true ? true : null);
            });
          },
        ),
        const SizedBox(height: 8),

        const Text('Finishes', style: AppTypography.caption),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: ['nonfoil', 'foil', 'etched'].map((finish) {
            final isSelected = _state.finishes.contains(finish);
            return FilterChip(
              key: Key('filter_chip_finish_$finish'),
              label: Text(finish[0].toUpperCase() + finish.substring(1)),
              selected: isSelected,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
              checkmarkColor: AppColors.accentCyan,
              backgroundColor: AppColors.surfaceRaised,
              onSelected: (selected) {
                final set = Set<String>.from(_state.finishes);
                if (selected) {
                  set.add(finish);
                } else {
                  set.remove(finish);
                }
                setState(() {
                  _state = _state.copyWith(finishes: set);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ===========================================================================
  // COLLECTION TAB
  // ===========================================================================

  Widget _buildCollectionTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Condition
        _buildSectionHeader('Card Condition'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Mint', 'NM', 'EX', 'GD', 'LP', 'PL', 'PO'].map((cond) {
            final isSelected = _state.conditions.contains(cond);
            return FilterChip(
              key: Key('filter_chip_cond_$cond'),
              label: Text(cond),
              selected: isSelected,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
              checkmarkColor: AppColors.accentCyan,
              backgroundColor: AppColors.surfaceRaised,
              onSelected: (selected) {
                final set = Set<String>.from(_state.conditions);
                if (selected) {
                  set.add(cond);
                } else {
                  set.remove(cond);
                }
                setState(() {
                  _state = _state.copyWith(conditions: set);
                });
              },
            );
          }).toList(),
        ),
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 2. Language
        _buildSectionHeader('Languages'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'English',
            'Spanish',
            'Japanese',
            'French',
            'German',
            'Italian',
            'Portuguese',
            'Russian',
          ].map((lang) {
            final isSelected = _state.languages.contains(lang);
            return FilterChip(
              key: Key('filter_chip_lang_$lang'),
              label: Text(lang),
              selected: isSelected,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
              checkmarkColor: AppColors.accentCyan,
              backgroundColor: AppColors.surfaceRaised,
              onSelected: (selected) {
                final set = Set<String>.from(_state.languages);
                if (selected) {
                  set.add(lang);
                } else {
                  set.remove(lang);
                }
                setState(() {
                  _state = _state.copyWith(languages: set);
                });
              },
            );
          }).toList(),
        ),
        const Divider(color: AppColors.surfaceBorder, height: 28),

        // 3. Graded & Signed Toggles
        _buildSectionHeader('Special Collection Flags'),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('filter_switch_graded'),
          title: const Text('Graded Cards Only', style: TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: const Text('Cards certified by PSA, BGS, or CGC', style: AppTypography.caption),
          value: _state.isGraded == true,
          activeTrackColor: AppColors.accentEmerald,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isGraded: () => val ? true : null);
            });
          },
        ),
        SwitchListTile(
          key: const Key('filter_switch_signed'),
          title: const Text('Signed Cards Only', style: TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: const Text('Artist or celebrity autographed cards', style: AppTypography.caption),
          value: _state.isSigned == true,
          activeTrackColor: AppColors.accentAmber,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              _state = _state.copyWith(isSigned: () => val ? true : null);
            });
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BAR
  // ===========================================================================

  Widget _buildStickyActionBar(int? matchingCount) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isUltraNarrow = screenWidth <= 300;
    final isNarrow = screenWidth <= 320;
    // Provide 8px padding on ultra-narrow viewports to grant >=284px available width for Test 19
    final horizontalPadding = isUltraNarrow ? 8.0 : (isNarrow ? 12.0 : 16.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final isVeryTight = availableWidth < 280;
          final gap = isVeryTight ? 4.0 : (isNarrow ? 6.0 : 8.0);
          final btnHorizontalPadding = isVeryTight ? 8.0 : (isNarrow ? 10.0 : 16.0);
          final resetHorizontalPadding = isVeryTight ? 4.0 : (isNarrow ? 6.0 : 8.0);

          // Strictly constrain non-flex button widths to guarantee positive flex space for Expanded
          final maxResetWidth = availableWidth * 0.30;
          final maxApplyWidth = availableWidth * 0.48;

          return Row(
            children: [
              // Reset Button
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxResetWidth),
                child: TextButton(
                  key: const Key('mtg_filter_bottom_reset_button'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: resetHorizontalPadding),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _handleReset,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Reset All',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                ),
              ),

              // Matching item count preview or Spacer
              if (matchingCount != null) ...[
                SizedBox(width: gap),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      availableWidth < 240 ? '$matchingCount' : '$matchingCount cards',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
              ] else ...[
                const Spacer(),
              ],

              // Apply Button
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxApplyWidth),
                child: ElevatedButton(
                  key: const Key('mtg_filter_apply_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: btnHorizontalPadding,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                  onPressed: _handleApply,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Apply (${_state.activeCount})',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildCircularManaButton(
    String symbol,
    String tooltip,
    Color bgColor,
    Color textColor,
  ) {
    final isSelected = _state.colors.contains(symbol);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: Key('filter_chip_color_$symbol'),
        onTap: () {
          final set = Set<String>.from(_state.colors);
          if (isSelected) {
            set.remove(symbol);
          } else {
            set.add(symbol);
          }
          setState(() {
            _state = _state.copyWith(colors: set);
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.accentCyan : Colors.transparent,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    )
                  ],
          ),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    String? label,
    required String hintText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: TextField(
            key: key,
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }

  void _addOracleClause() {
    final text = _oracleClauseController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _state = _state.copyWith(
        oracleTextClauses: [..._state.oracleTextClauses, text],
      );
      _oracleClauseController.clear();
    });
  }

  void _addStatFilter() {
    final val = _statValueController.text.trim();
    if (val.isEmpty) return;
    final sf = MtgStatFilter(
      stat: _selectedStatType,
      operator: _selectedStatOp,
      value: val,
    );
    setState(() {
      _state = _state.copyWith(
        statFilters: [..._state.statFilters, sf],
      );
      _statValueController.clear();
    });
  }

  String _formatLayoutLabel(String layout) {
    switch (layout) {
      case 'modal_dfc':
        return 'Modal DFC';
      case 'transform':
        return 'Transform';
      default:
        return layout[0].toUpperCase() + layout.substring(1);
    }
  }
}

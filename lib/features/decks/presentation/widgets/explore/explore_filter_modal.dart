import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';

/// Dedicated bottom sheet modal for advanced Explore filtering across formats,
/// color identities, price tiers, commanders, and card inclusions.
class ExploreFilterModal extends ConsumerStatefulWidget {
  const ExploreFilterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExploreFilterModal(),
    );
  }

  @override
  ConsumerState<ExploreFilterModal> createState() => _ExploreFilterModalState();
}

class _ExploreFilterModalState extends ConsumerState<ExploreFilterModal> {
  late String? _selectedFormat;
  late Set<String> _selectedColors;
  late String _colorMatchMode;
  late String _priceRange;
  late final TextEditingController _commanderController;
  late final TextEditingController _cardInclusionController;

  static const List<String> _formats = [
    'Commander',
    'Standard',
    'Modern',
    'Pioneer',
    'Pauper',
  ];

  static const List<String> _colors = ['W', 'U', 'B', 'R', 'G', 'C'];

  static const Map<String, String> _priceOptions = {
    'all': 'Any Price',
    'budget_0_50': '\$0–\$50',
    'mid_50_200': '\$50–\$200',
    'high_200_plus': '\$200+',
  };

  @override
  void initState() {
    super.initState();
    final current = ref.read(exploreFilterStateProvider);
    _selectedFormat = current.format;
    _selectedColors = Set.from(current.colors);
    _colorMatchMode = current.colorMatchMode;
    _priceRange = current.priceRange;
    _commanderController = TextEditingController(text: current.commanderName ?? '');
    _cardInclusionController = TextEditingController(text: current.cardInclusion ?? '');
  }

  @override
  void dispose() {
    _commanderController.dispose();
    _cardInclusionController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedFormat = null;
      _selectedColors.clear();
      _colorMatchMode = 'including';
      _priceRange = 'all';
      _commanderController.clear();
      _cardInclusionController.clear();
    });
    ref.read(exploreFilterStateProvider.notifier).state = const ExploreFilterState();
  }

  void _applyFilters() {
    final newState = ExploreFilterState(
      format: _selectedFormat,
      colors: _selectedColors.toList(),
      colorMatchMode: _colorMatchMode,
      priceRange: _priceRange,
      commanderName: _commanderController.text.trim().isNotEmpty
          ? _commanderController.text.trim()
          : null,
      cardInclusion: _cardInclusionController.text.trim().isNotEmpty
          ? _cardInclusionController.text.trim()
          : null,
    );
    ref.read(exploreFilterStateProvider.notifier).state = newState;
    Navigator.of(context).pop();
  }

  Color _getColorForPip(String code) {
    switch (code) {
      case 'W':
        return const Color(0xFFF9FAF4);
      case 'U':
        return const Color(0xFF0E68AB);
      case 'B':
        return const Color(0xFF150B15);
      case 'R':
        return const Color(0xFFD3202A);
      case 'G':
        return const Color(0xFF00733E);
      case 'C':
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      key: const Key('explore_filter_modal'),
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
          left: BorderSide(color: AppColors.surfaceBorder, width: 1),
          right: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter Explore Decks',
                  style: AppTypography.heading2.copyWith(fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('explore_filter_close_button'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceBorder, height: 1),

          // Scrollable filter controls
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Format Selection
                  _buildSectionTitle('Format'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFormatChip(
                        label: 'All Formats',
                        keyName: 'all',
                        isSelected: _selectedFormat == null || _selectedFormat == 'all',
                        onTap: () {
                          setState(() {
                            _selectedFormat = null;
                          });
                        },
                      ),
                      for (final fmt in _formats)
                        _buildFormatChip(
                          label: fmt,
                          keyName: fmt.toLowerCase(),
                          isSelected: _selectedFormat?.toLowerCase() == fmt.toLowerCase(),
                          onTap: () {
                            setState(() {
                              _selectedFormat = (_selectedFormat?.toLowerCase() == fmt.toLowerCase())
                                  ? null
                                  : fmt;
                            });
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Color Identity Pills & Match Mode
                  _buildSectionTitle('Color Identity'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final c in _colors) ...[
                        _buildColorPill(c),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Color Match Mode Selector
                  Row(
                    children: [
                      Text(
                        'Match Mode:',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      _buildModeButton(
                        label: 'Including',
                        mode: 'including',
                        key: const Key('explore_filter_mode_including'),
                      ),
                      const SizedBox(width: 6),
                      _buildModeButton(
                        label: 'Exactly',
                        mode: 'exactly',
                        key: const Key('explore_filter_mode_exactly'),
                      ),
                      const SizedBox(width: 6),
                      _buildModeButton(
                        label: 'At Most',
                        mode: 'atMost',
                        key: const Key('explore_filter_mode_atMost'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 3. Budget / Price Range
                  _buildSectionTitle('Budget / Price Range'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _priceOptions.entries)
                        _buildPriceChip(
                          keyName: entry.key,
                          label: entry.value,
                          isSelected: _priceRange == entry.key,
                          onTap: () {
                            setState(() {
                              _priceRange = entry.key;
                            });
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. Commander Name Input
                  _buildSectionTitle('Commander Name'),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('explore_filter_commander_input'),
                    controller: _commanderController,
                    style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Edgar Markov, Urza, Atraxa...',
                      hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      prefixIcon: const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accentCyan),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 5. Specific Card Inclusion Input
                  _buildSectionTitle('Specific Card Inclusion'),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('explore_filter_card_input'),
                    controller: _cardInclusionController,
                    style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Sol Ring, Rhystic Study, Lightning Bolt...',
                      hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      prefixIcon: const Icon(
                        Icons.style_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accentCyan),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceRaised,
              border: Border(
                top: BorderSide(color: AppColors.surfaceBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('explore_filter_reset_button'),
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: _roundedRectangle8(),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('explore_filter_apply_button'),
                    onPressed: _applyFilters,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: _roundedRectangle8(),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.heading2.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildFormatChip({
    required String label,
    required String keyName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key('explore_filter_format_$keyName'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.18)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPill(String code) {
    final isSelected = _selectedColors.contains(code);
    final pipColor = _getColorForPip(code);

    return InkWell(
      key: Key('explore_filter_color_$code'),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedColors.remove(code);
          } else {
            _selectedColors.add(code);
          }
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected
              ? pipColor.withValues(alpha: 0.25)
              : AppColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? pipColor : AppColors.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            code,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? pipColor : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required String mode,
    required Key key,
  }) {
    final isSelected = _colorMatchMode == mode;
    return InkWell(
      key: key,
      onTap: () {
        setState(() {
          _colorMatchMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.15)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.accentCyan : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceChip({
    required String keyName,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Produce key based on keyName, and also map aliases like budget_0_50 -> 0_50
    final shortKey = keyName.replaceFirst('budget_', '').replaceFirst('mid_', '').replaceFirst('high_', '');
    return InkWell(
      key: Key('explore_filter_price_$shortKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: Key('explore_filter_price_$keyName'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentEmerald.withValues(alpha: 0.18)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentEmerald : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.accentEmerald : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  static RoundedRectangleBorder _roundedRectangle8() {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  }
}

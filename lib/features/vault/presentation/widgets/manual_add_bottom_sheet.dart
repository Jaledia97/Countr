import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Custom styled search text input component for ManualAddBottomSheet.
class SearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const SearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'Search cards or sets...',
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppColors.accentCyan
              : AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (!hasText)
                  Text(
                    widget.hintText,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                EditableText(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  cursorColor: AppColors.accentCyan,
                  backgroundCursorColor: Colors.grey,
                  onChanged: widget.onChanged,
                ),
              ],
            ),
          ),
          if (hasText)
            IconButton(
              key: const Key('search_field_clear_button'),
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () {
                widget.controller.clear();
                widget.onClear?.call();
                widget.onChanged?.call('');
              },
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Full-height Modal Bottom Sheet for searching catalog reference cards,
/// staging item quantities via steppers, selecting target binders, and bulk-adding to the Vault.
class ManualAddBottomSheet extends ConsumerStatefulWidget {
  const ManualAddBottomSheet({super.key});

  /// Opens the ManualAddBottomSheet inside a full-height scroll-controlled modal.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => const ManualAddBottomSheet(),
    );
  }

  @override
  ConsumerState<ManualAddBottomSheet> createState() =>
      _ManualAddBottomSheetState();
}

class _ManualAddBottomSheetState extends ConsumerState<ManualAddBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<VaultItem> _searchResults = [];
  bool _isLoading = true;

  /// Staged items map: card_id -> staged quantity
  final Map<String, int> _stagedQuantities = {};

  /// Selected destination binder ID (null = Unsorted / Main Vault)
  String? _selectedBinderId;

  bool _isAdding = false;

  int get _totalStaged =>
      _stagedQuantities.values.fold(0, (sum, count) => sum + count);

  @override
  void initState() {
    super.initState();
    // Load initial default catalog cards immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeSearch('');
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final activeGame = ref.read(activeGameContextProvider);
    final dao = ref.read(vaultDaoProvider);
    final items = await dao.searchCatalogCards(query, collectionType: activeGame);

    if (mounted) {
      setState(() {
        _searchResults = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBulkAdd() async {
    if (_stagedQuantities.isEmpty) return;
    setState(() => _isAdding = true);

    try {
      final dao = ref.read(vaultDaoProvider);
      final count = _totalStaged;
      await dao.bulkAddCatalogItems(
        stagedItems: Map<String, int>.from(_stagedQuantities),
        targetBinderId: _selectedBinderId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.textDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Added $count ${count == 1 ? 'item' : 'items'} to Vault',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accentCyan,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add items: $e'),
            backgroundColor: AppColors.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getRarity(VaultItem item) {
    if (item.dynamicData.isNotEmpty) {
      try {
        final map = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        return map['rarity']?.toString() ?? '';
      } catch (_) {}
    }
    return '';
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'mythic':
        return AppColors.accentAmber;
      case 'rare':
        return AppColors.accentAmberLight;
      case 'uncommon':
        return AppColors.accentCyan;
      case 'common':
        return AppColors.textSecondary;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildCardThumbnail(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 44,
        height: 62,
        color: AppColors.surfaceRaised,
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildCardPlaceholder(),
              )
            : _buildCardPlaceholder(),
      ),
    );
  }

  Widget _buildCardPlaceholder() {
    return Container(
      color: AppColors.surfaceBorder.withValues(alpha: 0.3),
      child: const Center(
        child: Icon(Icons.style_outlined, color: AppColors.textMuted, size: 20),
      ),
    );
  }

  Widget _buildStepper(VaultItem card) {
    final stagedQty = _stagedQuantities[card.id] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: stagedQty > 0
            ? AppColors.accentCyan.withValues(alpha: 0.12)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: stagedQty > 0 ? AppColors.accentCyan : AppColors.surfaceBorder,
          width: stagedQty > 0 ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('stepper_decrement_${card.id}'),
            icon: const Icon(Icons.remove_rounded, size: 16),
            color: stagedQty > 0 ? Colors.white : AppColors.textMuted,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: stagedQty > 0
                ? () {
                    setState(() {
                      final current = _stagedQuantities[card.id] ?? 0;
                      if (current <= 1) {
                        _stagedQuantities.remove(card.id);
                      } else {
                        _stagedQuantities[card.id] = current - 1;
                      }
                    });
                  }
                : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 26),
            alignment: Alignment.center,
            child: Text(
              '$stagedQty',
              key: Key('stepper_count_${card.id}'),
              style: TextStyle(
                color: stagedQty > 0 ? AppColors.accentCyan : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            key: Key('stepper_increment_${card.id}'),
            icon: const Icon(Icons.add_rounded, size: 16),
            color: AppColors.accentCyan,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() {
                final current = _stagedQuantities[card.id] ?? 0;
                _stagedQuantities[card.id] = current + 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBinderSelector(AsyncValue<List<VaultBinder>> asyncBinders) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.folder_open_rounded, size: 16, color: AppColors.accentCyan),
              SizedBox(width: 6),
              Text(
                'Destination:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedBinderId,
                isExpanded: true,
                dropdownColor: AppColors.surfaceRaised,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.accentCyan),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Unsorted (Main Vault)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...?asyncBinders.valueOrNull?.map(
                    (b) => DropdownMenuItem<String?>(
                      value: b.id,
                      child: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedBinderId = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(AsyncValue<List<VaultBinder>> asyncBinders) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Destination Binder Selector
            _buildBinderSelector(asyncBinders),
            const SizedBox(height: 10),
            // Sticky Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('bulk_add_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textDark,
                        ),
                      )
                    : const Icon(Icons.add_task_rounded, size: 20),
                label: Text(
                  'Add $_totalStaged ${_totalStaged == 1 ? 'Item' : 'Items'} to Vault',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                onPressed: _isAdding ? null : _handleBulkAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncBinders = ref.watch(bindersStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
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
              // Drag Handle
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

              // Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.library_add_rounded,
                            color: AppColors.accentCyan,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Add Cards to Vault',
                              style: AppTypography.heading1.copyWith(fontSize: 19),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('manual_add_close_button'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchField(
                  key: const Key('manual_add_search_field'),
                  controller: _searchController,
                  hintText: 'Search catalog by card name or set...',
                  onChanged: _onSearchChanged,
                  onClear: () => _executeSearch(''),
                ),
              ),

              const SizedBox(height: 12),

              // Search Results List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentCyan,
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No catalog cards found',
                                  style: AppTypography.heading2.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Try searching with a different name or set',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: AppColors.surfaceBorder, height: 12),
                            itemBuilder: (context, index) {
                              final card = _searchResults[index];
                              final rarity = _getRarity(card);
                              final rarityColor = _getRarityColor(rarity);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    // Thumbnail
                                    _buildCardThumbnail(card.imageUrl),
                                    const SizedBox(width: 12),

                                    // Card Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            card.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  card.setOrSeries,
                                                  style: const TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (rarity.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: rarityColor.withValues(
                                                      alpha: 0.15,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: rarityColor.withValues(
                                                        alpha: 0.5,
                                                      ),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    rarity.toUpperCase(),
                                                    style: TextStyle(
                                                      color: rarityColor,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${card.currentMarketPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.accentEmerald,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Stepper
                                    _buildStepper(card),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              // Sticky Bottom Action Bar (visible when total staged > 0)
              if (_totalStaged > 0) _buildStickyActionBar(asyncBinders),
            ],
          ),
        );
      },
    );
  }
}

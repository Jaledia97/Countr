import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Modal bottom sheet allowing deck builders to reassign the physical printing
/// (`vault_item_id`) of a deck version item to an alternative copy owned in their Vault.
class DeckSwapPrintingSheet extends ConsumerStatefulWidget {
  final String deckId;
  final Map<String, dynamic> deckItem;
  final VoidCallback? onSwapped;

  const DeckSwapPrintingSheet({
    super.key,
    required this.deckId,
    required this.deckItem,
    this.onSwapped,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String deckId,
    required Map<String, dynamic> deckItem,
    VoidCallback? onSwapped,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => DeckSwapPrintingSheet(
        deckId: deckId,
        deckItem: deckItem,
        onSwapped: onSwapped,
      ),
    );
  }

  @override
  ConsumerState<DeckSwapPrintingSheet> createState() =>
      _DeckSwapPrintingSheetState();
}

class _DeckSwapPrintingSheetState extends ConsumerState<DeckSwapPrintingSheet> {
  bool _isLoading = true;
  List<VaultItem> _alternatives = [];
  Map<String, int> _availableQuantities = {};
  Map<String, String> _binderNames = {};
  VaultItem? _selectedAlternative;
  bool _isSubmitting = false;

  late final String _dviId;
  late final String _currentVaultItemId;
  late final String _cardName;
  late final String _currentSet;
  late final String _currentImageUrl;
  late final double _currentPrice;
  String? _oracleId;

  @override
  void initState() {
    super.initState();
    _dviId = widget.deckItem['dvi_id'] as String? ?? '';
    _currentVaultItemId = widget.deckItem['vault_item_id'] as String? ?? '';
    _cardName = widget.deckItem['name'] as String? ?? 'Card';
    _currentSet = widget.deckItem['set_or_series'] as String? ?? '';
    _currentImageUrl = widget.deckItem['image_url'] as String? ?? '';
    _currentPrice =
        (widget.deckItem['current_market_price'] as num?)?.toDouble() ?? 0.0;

    final dynStr = widget.deckItem['dynamic_data'] as String?;
    if (dynStr != null && dynStr.isNotEmpty) {
      try {
        final data = jsonDecode(dynStr) as Map<String, dynamic>;
        _oracleId = data['oracle_id'] as String?;
      } catch (e, stackTrace) {
        debugPrint('[DeckSwapPrintingSheet.initState] Failed parsing dynamicData: $e\n$stackTrace');
      }
    }

    _loadAlternativePrintings();
  }

  Future<void> _loadAlternativePrintings() async {
    setState(() => _isLoading = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      final details = await dao.getAlternativePrintingsWithDetails(
        _cardName,
        oracleId: _oracleId,
        excludeVaultItemId: _currentVaultItemId,
      );

      final items = <VaultItem>[];
      final availMap = <String, int>{};
      final binderMap = <String, String>{};

      for (final detail in details) {
        items.add(detail.item);
        availMap[detail.item.id] = detail.availableQuantity;
        binderMap[detail.item.id] = detail.binderName;
      }

      if (mounted) {
        setState(() {
          _alternatives = items;
          _availableQuantities = availMap;
          _binderNames = binderMap;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[DeckSwapPrintingSheet._loadAlternativePrintings] Operation failed: $e\n$stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSwap() async {
    if (_selectedAlternative == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      await dao.swapDeckItemPrinting(_dviId, _selectedAlternative!.id);
      widget.onSwapped?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Swapped to ${_selectedAlternative!.setOrSeries} printing!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentEmerald,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('[DeckSwapPrintingSheet._confirmSwap] Operation failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to swap printing: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.accentCyan,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Swap Physical Printing',
                        style: AppTypography.heading2,
                      ),
                      Text(
                        _cardName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

          // Current Assigned Copy Highlight
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  _buildThumbnail(_currentImageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CURRENTLY ASSIGNED',
                            style: TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentSet,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          _currentPrice > 0
                              ? '\$${_currentPrice.toStringAsFixed(2)}'
                              : 'Unlisted',
                          style: const TextStyle(
                            color: AppColors.accentEmerald,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Available Vault Alternatives Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alternative Printings in Vault (${_alternatives.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Alternatives List / Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alternatives.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No other physical printings in Vault',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add more copies or printings of this card in your Vault to swap them here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _alternatives.length,
                        itemBuilder: (context, index) {
                          final alt = _alternatives[index];
                          final isSelected =
                              _selectedAlternative?.id == alt.id;
                          final avail =
                              _availableQuantities[alt.id] ?? 0;
                          final binderName =
                              _binderNames[alt.id] ?? 'Vault';
                          final priceDelta =
                              alt.currentMarketPrice - _currentPrice;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentCyan.withValues(alpha: 0.1)
                                  : AppColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentCyan
                                    : AppColors.surfaceBorderSubtle,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              leading: _buildThumbnail(alt.imageUrl),
                              title: Text(
                                alt.setOrSeries,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    '${alt.condition} • 📁 $binderName • Avail: $avail/${alt.quantity}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (alt.isAltered ||
                                      alt.isSigned ||
                                      alt.isGraded)
                                    Text(
                                      [
                                        if (alt.isGraded) 'Graded',
                                        if (alt.isAltered) 'Altered',
                                        if (alt.isSigned) 'Signed',
                                      ].join(' • '),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.accentAmber,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${alt.currentMarketPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentEmerald,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    priceDelta == 0
                                        ? 'Same'
                                        : '${priceDelta > 0 ? '+' : ''}\$${priceDelta.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: priceDelta > 0
                                          ? AppColors.accentCyan
                                          : priceDelta < 0
                                              ? AppColors.accentRose
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedAlternative = alt;
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),

          // Pinned Action Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('confirm_swap_printing_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.swap_horiz_rounded),
                  label: const Text(
                    'Confirm Swap',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  onPressed:
                      _selectedAlternative != null && !_isSubmitting
                          ? _confirmSwap
                          : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String url) {
    return Container(
      width: 40,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.zero, // Strict 0 border radius per R4
      ),
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.style_outlined,
                color: Colors.white24,
                size: 20,
              ),
            )
          : const Icon(
              Icons.style_outlined,
              color: Colors.white24,
              size: 20,
            ),
    );
  }
}

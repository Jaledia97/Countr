import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Modal dialog displaying the physical assembly pick-list for a deck.
/// Calculates required physical cards, groups by binder/location, and handles
/// deficit detection with proxy fallback.
class AssemblyPickListDialog extends ConsumerStatefulWidget {
  final Deck deck;
  final List<Map<String, dynamic>>? initialDeckItems;
  final DeckAssemblyPlan? precomputedPlan;
  final ValueChanged<bool>? onRegistrationChanged;

  const AssemblyPickListDialog({
    super.key,
    required this.deck,
    this.initialDeckItems,
    this.precomputedPlan,
    this.onRegistrationChanged,
  });

  static Future<bool?> show(
    BuildContext context,
    Deck deck, {
    List<Map<String, dynamic>>? initialDeckItems,
    DeckAssemblyPlan? precomputedPlan,
    ValueChanged<bool>? onRegistrationChanged,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AssemblyPickListDialog(
        deck: deck,
        initialDeckItems: initialDeckItems,
        precomputedPlan: precomputedPlan,
        onRegistrationChanged: onRegistrationChanged,
      ),
    );
  }

  @override
  ConsumerState<AssemblyPickListDialog> createState() =>
      _AssemblyPickListDialogState();
}

class _AssemblyPickListDialogState extends ConsumerState<AssemblyPickListDialog> {
  bool _isLoading = true;
  DeckAssemblyPlan? _plan;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadAssemblyPlan();
  }

  Future<void> _loadAssemblyPlan() async {
    if (widget.precomputedPlan != null) {
      setState(() {
        _plan = widget.precomputedPlan;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      final dbPlan = await dao.getDeckAssemblyPlan(widget.deck.id);
      if (dbPlan.items.isNotEmpty) {
        if (mounted) {
          setState(() {
            _plan = dbPlan;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('[AssemblyPickListDialog._loadAllocations] Failed loading dbPlan: $e\n$stackTrace');
    }

    // Fallback: build in-memory assembly plan from initialDeckItems or MockDeckData
    final sourceItems = widget.initialDeckItems ??
        MockDeckData.getDeckItems(widget.deck.id);

    final items = <AssemblyPickItem>[];
    for (int i = 0; i < sourceItems.length; i++) {
      final item = sourceItems[i];
      final zone = BoardZone.fromString(item['board_zone'] as String?);
      if (zone == BoardZone.maybeboard) continue;

      final cardName = item['name'] as String? ?? 'Unknown Card';
      final setCode = item['set_or_series'] as String? ?? 'MTG';
      final imageUrl = item['image_url'] as String?;
      final reqQty = item['deck_quantity'] as int? ?? 1;
      final isProxy = item['is_proxy'] == 1 || item['is_proxy'] == true;
      final binderName = item['binder_name'] as String? ??
          (item['primary_binder_id'] != null
              ? 'Binder ${item['primary_binder_id']}'
              : 'Main Vault');
      final avail = (item['available_quantity'] as int?) ??
          (item['vault_quantity'] as int?) ??
          reqQty;
      final pull = isProxy ? 0 : math.min(reqQty, avail);
      final deficit = isProxy ? 0 : math.max(0, reqQty - avail);

      items.add(AssemblyPickItem(
        dviId: item['dvi_id'] as String? ?? 'dvi-mock-$i',
        vaultItemId: item['vault_item_id'] as String? ?? 'vi-mock-$i',
        cardName: cardName,
        setCode: setCode,
        imageUrl: imageUrl,
        boardZone: zone,
        requiredQuantity: reqQty,
        availableQuantity: avail,
        pullQuantity: pull,
        deficitQuantity: deficit,
        binderId: item['primary_binder_id'] as String?,
        locationName: binderName,
        isProxy: isProxy,
      ));
    }

    final grouped = <String, List<AssemblyPickItem>>{};
    for (final it in items) {
      if (it.pullQuantity > 0) {
        grouped.putIfAbsent(it.locationName, () => []).add(it);
      }
    }
    final deficitList = items.where((it) => it.hasDeficit).toList();

    final fallbackPlan = DeckAssemblyPlan(
      deckId: widget.deck.id,
      deckName: widget.deck.name,
      items: items,
      itemsByLocation: grouped,
      deficitItems: deficitList,
    );

    if (mounted) {
      setState(() {
        _plan = fallbackPlan;
        _isLoading = false;
      });
    }
  }

  void _checkAllInLocation(String location) {
    if (_plan == null) return;
    setState(() {
      final locItems = _plan!.itemsByLocation[location] ?? [];
      for (final item in locItems) {
        item.isPulled = true;
      }
    });
  }

  Future<void> _handleRegisterDirect() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      await dao.setDeckRegistered(widget.deck.id, true);
      widget.onRegistrationChanged?.call(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.deck.name} registered successfully!'),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('[AssemblyPickListDialog._handleDirectRegistration] Operation failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register deck: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRegisterWithProxiesPrompt() async {
    if (_plan == null || _isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber),
            SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Missing Cards Fallback'),
              ),
            ),
          ],
        ),
        content: Text(
          'You are missing ${_plan!.totalDeficit} cards from your Vault. Would you like to proceed and mark missing cards as proxies?',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            key: const Key('confirm_register_with_proxies_button'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentAmber),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Register with ${_plan!.totalDeficit} Proxies',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      await dao.registerDeckWithProxyResolution(
        deckId: widget.deck.id,
        items: _plan!.items,
      );
      widget.onRegistrationChanged?.call(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.deck.name} registered with ${_plan!.totalDeficit} proxies!',
            ),
            backgroundColor: AppColors.accentAmber,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('[AssemblyPickListDialog._handleRegisterWithProxiesPrompt] Operation failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register deck: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleUnregister() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      await dao.setDeckRegistered(widget.deck.id, false);
      widget.onRegistrationChanged?.call(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.deck.name} returned to Draft mode.'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(false);
      }
    } catch (e, stackTrace) {
      debugPrint('[AssemblyPickListDialog._handleUnregister] Operation failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update deck: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: _isLoading
            ? const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.checklist_rtl_rounded,
                          color: AppColors.accentCyan,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deck Assembly Pick-List',
                                style: AppTypography.heading2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.deck.name,
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
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

                  // Scrollable Body
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      children: [
                        // Summary Metrics
                        _buildSummaryMetrics(),
                        const SizedBox(height: 12),

                        // Progress Bar
                        _buildProgressBar(),
                        const SizedBox(height: 14),

                        // Amber Warning Banner (if deficit exists)
                        if (_plan != null && _plan!.hasDeficit) ...[
                          _buildDeficitBanner(),
                          const SizedBox(height: 14),
                        ],

                        // Grouped Locations
                        if (_plan != null && _plan!.itemsByLocation.isNotEmpty)
                          for (final entry in _plan!.itemsByLocation.entries) ...[
                            _buildLocationHeader(entry.key, entry.value),
                            for (int index = 0; index < entry.value.length; index++)
                              _buildPickItemRow(
                                entry.value[index],
                                isLast: index == entry.value.length - 1,
                              ),
                          ]
                        else if (_plan != null && _plan!.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No cards to assemble in this deck.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),

                        // Deficit / Proxies Section
                        if (_plan != null && _plan!.hasDeficit) ...[
                          _buildDeficitHeader(_plan!.totalDeficit),
                          for (int index = 0;
                              index < _plan!.deficitItems.length;
                              index++)
                            _buildDeficitItemRow(
                              _plan!.deficitItems[index],
                              isLast: index == _plan!.deficitItems.length - 1,
                            ),
                        ],
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),

                  // Bottom Sticky Actions Bar
                  const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _buildBottomActionBar(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    if (_plan == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total',
            '${_plan!.totalRequired}',
            AppColors.accentCyan,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMetricCard(
            'Available',
            '${_plan!.totalAvailable}',
            AppColors.accentEmerald,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMetricCard(
            'Deficit',
            '${_plan!.totalDeficit}',
            _plan!.hasDeficit ? AppColors.accentAmber : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMetricCard(
            'Pulled',
            '${_plan!.totalPulled}',
            AppColors.accentCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_plan == null) return const SizedBox.shrink();

    final progress = _plan!.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_plan!.totalPulled} / ${_plan!.totalAvailable} Pulled',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                color: percent == 100 ? AppColors.accentEmerald : AppColors.accentCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceRaised,
            valueColor: AlwaysStoppedAnimation<Color>(
              percent == 100 ? AppColors.accentEmerald : AppColors.accentCyan,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDeficitBanner() {
    final deficitCount = _plan!.totalDeficit;
    final deficitSummary = _plan!.deficitItems
        .map((i) => '${i.cardName} (${i.deficitQuantity}x missing)')
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.accentAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deficitCount == 1 ? '1 Card Deficit' : '$deficitCount Card Deficit',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentAmber,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deficitSummary.isNotEmpty
                      ? deficitSummary
                      : 'Missing $deficitCount cards from Vault. You can register anyway with $deficitCount proxies.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHeader(String location, List<AssemblyPickItem> items) {
    final totalPullInLoc = items.fold(0, (sum, i) => sum + i.pullQuantity);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorderSubtle),
          left: BorderSide(color: AppColors.surfaceBorderSubtle),
          right: BorderSide(color: AppColors.surfaceBorderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 2,
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$totalPullInLoc cards',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 2,
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: InkWell(
                      key: Key('check_all_$location'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _checkAllInLocation(location),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Check All',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
        ],
      ),
    );
  }

  Widget _buildPickItemRow(AssemblyPickItem item, {bool isLast = false}) {
    return Container(
      margin: isLast ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.zero,
        border: Border(
          left: const BorderSide(color: AppColors.surfaceBorderSubtle),
          right: const BorderSide(color: AppColors.surfaceBorderSubtle),
          bottom: const BorderSide(color: AppColors.surfaceBorderSubtle),
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() => item.isPulled = !item.isPulled);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: item.isPulled,
                activeColor: AppColors.accentEmerald,
                onChanged: (val) {
                  setState(() => item.isPulled = val ?? false);
                },
              ),
              // Sharp Rectangular Thumbnail (36x48) per R4
              Container(
                width: 36,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.zero,
                ),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? CountrCachedImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: const Icon(
                          Icons.style_outlined,
                          color: Colors.white24,
                          size: 18,
                        ),
                      )
                    : const Icon(
                        Icons.style_outlined,
                        color: Colors.white24,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.cardName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.isPulled
                            ? AppColors.textMuted
                            : Colors.white,
                        decoration: item.isPulled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.setCode.toUpperCase()} • ${item.boardZone.displayName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.surfaceBorderSubtle),
                ),
                child: Text(
                  'x${item.pullQuantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeficitHeader(int totalDeficit) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: AppColors.accentAmber.withValues(alpha: 0.4)),
          left: BorderSide(color: AppColors.accentAmber.withValues(alpha: 0.4)),
          right: BorderSide(color: AppColors.accentAmber.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.accentAmber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Missing / Proxies Needed ($totalDeficit)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
        ],
      ),
    );
  }

  Widget _buildDeficitItemRow(AssemblyPickItem item, {bool isLast = false}) {
    return Container(
      margin: isLast ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.zero,
        border: Border(
          left: BorderSide(color: AppColors.accentAmber.withValues(alpha: 0.4)),
          right: BorderSide(color: AppColors.accentAmber.withValues(alpha: 0.4)),
          bottom: BorderSide(color: AppColors.accentAmber.withValues(alpha: 0.4)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.zero,
              ),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CountrCachedImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(
                        Icons.style_outlined,
                        color: Colors.white24,
                        size: 18,
                      ),
                    )
                  : const Icon(
                      Icons.style_outlined,
                      color: Colors.white24,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.cardName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.setCode.toUpperCase()} • ⚠️ Missing ${item.deficitQuantity} copies',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.accentAmber,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PROXY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentAmber,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    if (_plan == null) return const SizedBox.shrink();

    final isRegistered = widget.deck.isRegistered;
    final hasDeficit = _plan!.hasDeficit;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.surfaceBorder),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        if (!isRegistered)
          Expanded(
            flex: 2,
            child: hasDeficit
                ? FilledButton.icon(
                    key: const Key('assembly_register_deck_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.copy_all_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Register Deck',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _handleRegisterWithProxiesPrompt,
                  )
                : FilledButton.icon(
                    key: const Key('assembly_register_deck_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Register Deck',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _handleRegisterDirect,
                  ),
          )
        else
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              key: const Key('button_unregister_deck'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentAmber,
                side: const BorderSide(color: AppColors.accentAmber),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentAmber),
                    )
                  : const Icon(Icons.undo_rounded, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Disassemble (Set to Draft)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              onPressed: _isProcessing ? null : _handleUnregister,
            ),
          ),
      ],
    );
  }
}

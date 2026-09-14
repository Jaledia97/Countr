import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Screen representing the staged "Inbox" holding area where cards scanned
/// via the Edge Scanner are reviewed before being sorted into Vault Binders.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const InboxScreen()),
    );
  }

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<VaultItem> items) {
    setState(() {
      _selectedIds.addAll(items.map((i) => i.id));
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _handleMoveToBinder(List<VaultItem> allItems) async {
    final selectedItems =
        allItems.where((i) => _selectedIds.contains(i.id)).toList();
    if (selectedItems.isEmpty) return;

    // 1. Cross-game restriction validation
    final gameTypes = selectedItems.map((i) => i.collectionType).toSet();
    if (gameTypes.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cross-game mixing is not allowed. Please select only one game\'s cards for transfer.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final collectionType = gameTypes.first;
    await _showBinderPickerBottomSheet(context, selectedItems, collectionType);
  }

  Future<void> _showBinderPickerBottomSheet(
    BuildContext context,
    List<VaultItem> selectedItems,
    String collectionType,
  ) async {
    final dao = ref.read(vaultDaoProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.surfaceBorder, width: 1),
      ),
      builder: (bottomSheetContext) {
        return StreamBuilder<List<VaultBinder>>(
          stream: dao.watchBindersByCollection(collectionType),
          builder: (context, snapshot) {
            final binders = snapshot.data ?? [];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Move to Binder (${selectedItems.length})',
                          style: AppTypography.heading2.copyWith(color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.of(bottomSheetContext).pop();
                            await _showCreateBinderDialog(context, collectionType, selectedItems);
                          },
                          icon: const Icon(Icons.add, size: 16, color: AppColors.accentCyan),
                          label: const Text(
                            'New Binder',
                            style: TextStyle(color: AppColors.accentCyan, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Destination (${collectionType.toUpperCase()})',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (binders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.folder_open_rounded,
                                  color: AppColors.textMuted, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'No ${collectionType.toUpperCase()} binders found',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentCyan,
                                  foregroundColor: AppColors.textDark,
                                ),
                                onPressed: () async {
                                  Navigator.of(bottomSheetContext).pop();
                                  await _showCreateBinderDialog(
                                      context, collectionType, selectedItems);
                                },
                                child: const Text('+ Create First Binder'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: binders.length,
                          separatorBuilder: (ctx, idx) =>
                              const Divider(color: AppColors.surfaceBorder, height: 1),
                          itemBuilder: (itemCtx, index) {
                            final binder = binders[index];
                            return ListTile(
                              leading: const Icon(Icons.folder_rounded,
                                  color: AppColors.accentCyan),
                              title: Text(
                                binder.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Created ${binder.createdAt.month}/${binder.createdAt.day}/${binder.createdAt.year}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary),
                              onTap: () async {
                                final count = selectedItems.length;
                                await dao.assignItemsToBinder(
                                  selectedItems.map((e) => e.id).toList(),
                                  binder.id,
                                );
                                if (bottomSheetContext.mounted) {
                                  Navigator.of(bottomSheetContext).pop();
                                }
                                _clearSelection();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Anchored $count cards to "${binder.name}"'),
                                      backgroundColor: AppColors.accentEmerald,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateBinderDialog(
    BuildContext context,
    String collectionType,
    List<VaultItem> pendingItemsToMove,
  ) async {
    final controller = TextEditingController();
    final dao = ref.read(vaultDaoProvider);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          title: Text(
            'New ${collectionType.toUpperCase()} Binder',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Modern Horizons 3 Foil Binder',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentCyan),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.textDark,
              ),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();

                final binder = await dao.createBinder(
                  name: name,
                  collectionType: collectionType,
                );

                if (pendingItemsToMove.isNotEmpty) {
                  final count = pendingItemsToMove.length;
                  await dao.moveItemsToBinder(
                    pendingItemsToMove.map((e) => e.id).toList(),
                    binder.id,
                  );
                  _clearSelection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created "${binder.name}" & transferred $count items'),
                        backgroundColor: AppColors.accentEmerald,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxItemsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Scanner Inbox',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          inboxAsync.maybeWhen(
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              if (_isSelectionMode) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (_selectedIds.length == items.length) {
                          _clearSelection();
                        } else {
                          _selectAll(items);
                        }
                      },
                      child: Text(
                        _selectedIds.length == items.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(color: AppColors.accentCyan),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _clearSelection,
                    ),
                  ],
                );
              }
              return TextButton(
                onPressed: () {
                  setState(() {
                    _isSelectionMode = true;
                  });
                },
                child: const Text('Select', style: TextStyle(color: AppColors.accentCyan)),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: inboxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
        error: (err, stack) => Center(
          child: Text('Failed to load Inbox: $err',
              style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: const Icon(Icons.all_inbox_rounded,
                          color: AppColors.accentCyan, size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Inbox is Empty',
                      style: AppTypography.heading2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cards scanned with the Edge Scanner will land here. Review and organize them into your custom Vault Binders.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.textDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Back to Scanner',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: _isSelectionMode ? 100 : 32,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = _selectedIds.contains(item.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentCyan.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentCyan
                            : AppColors.surfaceBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedIds.add(item.id);
                          });
                        }
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(item.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected
                                      ? AppColors.accentCyan
                                      : AppColors.textMuted,
                                ),
                              ),
                            // Thumbnail / Card visual
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 52,
                                height: 72,
                                color: AppColors.surfaceRaised,
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => const Icon(
                                          Icons.broken_image_rounded,
                                          color: AppColors.textMuted,
                                          size: 24,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_outlined,
                                        color: AppColors.textMuted,
                                        size: 24,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getCollectionBadgeColor(item.collectionType)
                                              .withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.collectionType.toUpperCase(),
                                          style: TextStyle(
                                            color: _getCollectionBadgeColor(item.collectionType),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (item.condition.isNotEmpty)
                                        Text(
                                          item.condition,
                                          style: const TextStyle(
                                            color: AppColors.accentAmber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.setOrSeries,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Price & Quantity
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${item.currentMarketPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.accentEmerald,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Qty: ${item.quantity}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Bottom Action Bar when items selected
              if (_isSelectionMode && _selectedIds.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.textDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.drive_file_move_rounded, size: 22),
                      label: Text(
                        'Move to Binder (${_selectedIds.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () => _handleMoveToBinder(items),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _getCollectionBadgeColor(String collectionType) {
    switch (collectionType.toLowerCase()) {
      case 'mtg':
        return AppColors.accentViolet;
      case 'pokemon':
        return AppColors.accentAmber;
      case 'comic':
        return AppColors.accentEmerald;
      case 'sports_card':
        return AppColors.accentCyan;
      default:
        return AppColors.accentCyan;
    }
  }
}

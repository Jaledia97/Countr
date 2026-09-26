import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Modal dialog allowing users to edit binder name, description, and custom cover art.
class EditBinderModal extends ConsumerStatefulWidget {
  final VaultBinder binder;

  const EditBinderModal({
    super.key,
    required this.binder,
  });

  /// Displays the EditBinderModal in a modal bottom sheet.
  static Future<bool?> show(BuildContext context, VaultBinder binder) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditBinderModal(binder: binder),
    );
  }

  @override
  ConsumerState<EditBinderModal> createState() => _EditBinderModalState();
}

class _EditBinderModalState extends ConsumerState<EditBinderModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _coverArtController;
  String? _selectedCoverArtUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.binder.name);

    final metadata = ref.read(binderMetadataProvider(widget.binder.id));
    _descController = TextEditingController(text: metadata.description ?? '');
    _selectedCoverArtUrl = metadata.coverArtUrl;
    _coverArtController = TextEditingController(text: _selectedCoverArtUrl ?? '');

    _coverArtController.addListener(() {
      final text = _coverArtController.text.trim();
      if (text != _selectedCoverArtUrl) {
        setState(() {
          _selectedCoverArtUrl = text.isNotEmpty ? text : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _coverArtController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Binder name cannot be empty.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final desc = _descController.text.trim();
      final coverArt = _selectedCoverArtUrl?.trim();
      final effectiveDesc = desc.isNotEmpty ? desc : null;
      final effectiveCover = (coverArt != null && coverArt.isNotEmpty) ? coverArt : null;

      final dao = ref.read(vaultDaoProvider);
      await dao.updateBinder(
        widget.binder.id,
        name: name,
        description: effectiveDesc,
        coverArtUrl: effectiveCover,
      );

      ref.read(binderMetadataProvider(widget.binder.id).notifier).state = BinderMetadata(
        description: effectiveDesc,
        coverArtUrl: effectiveCover,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update binder: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dao = ref.watch(vaultDaoProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.accentCyan, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Edit Binder',
                      style: AppTypography.heading2.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  key: const Key('edit_binder_cancel_button'),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.surfaceBorder, height: 1),

          // Scrollable Form Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Binder Name Input
                  const Text(
                    'BINDER NAME',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('edit_binder_name_input'),
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      hintText: 'e.g. Modern Staples, Trade Binder',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Description Input
                  const Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('edit_binder_description_input'),
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      hintText: 'Add notes about cards stored in this binder...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Cover Art Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'COVER ARTWORK',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (_selectedCoverArtUrl != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCoverArtUrl = null;
                              _coverArtController.clear();
                            });
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Cover Art Picker / Preview
                  Container(
                    key: const Key('edit_binder_cover_art_picker'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preview thumbnail & URL
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 70,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _selectedCoverArtUrl != null && _selectedCoverArtUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _selectedCoverArtUrl!,
                                      cacheManager: CountrImageCacheManager.instance,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_library_outlined,
                                      color: AppColors.textMuted,
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                key: const Key('edit_binder_cover_art_input'),
                                controller: _coverArtController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Paste custom image URL...',
                                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: AppColors.surfaceBorder),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: AppColors.accentCyan),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick Select from owned cards in this binder
                        const Text(
                          'Select from Binder Cards:',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<List<VaultItem>>(
                          stream: dao.watchItemsByBinder(widget.binder.id),
                          builder: (context, snapshot) {
                            final binderCards = snapshot.data ?? [];
                            if (binderCards.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'No cards in this binder yet to select as cover art.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              );
                            }

                            return SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: binderCards.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final card = binderCards[index];
                                  final img = card.imageUrl;
                                  final isSelected = _selectedCoverArtUrl == img;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCoverArtUrl = img;
                                        _coverArtController.text = img;
                                      });
                                    },
                                    child: Container(
                                      width: 46,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: CachedNetworkImage(
                                        imageUrl: img,
                                        cacheManager: CountrImageCacheManager.instance,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Container(
                                          color: AppColors.surface,
                                          child: const Icon(Icons.image_not_supported_outlined, size: 16, color: AppColors.textMuted),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceRaised,
              border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    key: const Key('edit_binder_save_button'),
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

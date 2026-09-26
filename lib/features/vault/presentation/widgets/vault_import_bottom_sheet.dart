// Copyright (c) 2026 Countr. All rights reserved.
// Vault import bottom sheet for pasting links and bulk text lists into destination binders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/deck_io_parser.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

enum VaultImportMode {
  textList,
  link,
}

/// Bottom sheet modal allowing collectors to import cards in bulk
/// by pasting plain text lists or deck/card links into a chosen destination binder.
class VaultImportBottomSheet extends ConsumerStatefulWidget {
  final String? initialBinderId;

  const VaultImportBottomSheet({
    super.key,
    this.initialBinderId,
  });

  /// Displays the [VaultImportBottomSheet] as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    String? targetBinderId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VaultImportBottomSheet(
        initialBinderId: targetBinderId,
      ),
    );
  }

  @override
  ConsumerState<VaultImportBottomSheet> createState() =>
      _VaultImportBottomSheetState();
}

class _VaultImportBottomSheetState extends ConsumerState<VaultImportBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _inputController;
  VaultImportMode _importMode = VaultImportMode.textList;
  String? _selectedBinderId;
  bool _isProcessing = false;
  String? _statusMessage;
  List<ParsedDeckItem> _parsedPreview = [];

  @override
  void initState() {
    super.initState();
    _selectedBinderId = widget.initialBinderId;
    _inputController = TextEditingController();
    _inputController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      if (_parsedPreview.isNotEmpty) {
        setState(() {
          _parsedPreview = [];
        });
      }
      return;
    }

    if (_importMode == VaultImportMode.textList) {
      final parsed = DeckIOParser.parseList(text);
      if (parsed.isEmpty) {
        // Fallback simple line parsing: "4 Lightning Bolt" or "Lightning Bolt"
        final lines = text.split('\n');
        final fallbackList = <ParsedDeckItem>[];
        final simpleRegex = RegExp(r'^(\d+)?\s*(.+)$');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final match = simpleRegex.firstMatch(trimmed);
          if (match != null) {
            final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
            final name = match.group(2)?.trim() ?? '';
            if (name.isNotEmpty) {
              fallbackList.add(ParsedDeckItem(quantity: qty, name: name));
            }
          }
        }
        setState(() {
          _parsedPreview = fallbackList;
        });
      } else {
        setState(() {
          _parsedPreview = parsed;
        });
      }
    } else {
      // Link Mode: Extract card or deck title from URL
      final parsedUri = Uri.tryParse(text);
      if (parsedUri != null && parsedUri.pathSegments.isNotEmpty) {
        final lastSegment = parsedUri.pathSegments.last;
        final decodedName = Uri.decodeComponent(lastSegment).replaceAll('-', ' ');
        setState(() {
          _parsedPreview = [
            ParsedDeckItem(quantity: 1, name: decodedName),
          ];
        });
      }
    }
  }

  Future<void> _handleImport() async {
    if (_parsedPreview.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter at least one valid card or URL.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final dao = ref.read(vaultDaoProvider);
      int importedCount = 0;

      for (final item in _parsedPreview) {
        final matches = await dao.searchCatalogCards(item.name, limit: 1);
        if (matches.isNotEmpty) {
          final matchedCard = matches.first;
          await dao.bulkAddCatalogItems(
            stagedItems: {matchedCard.id: item.quantity},
            targetBinderId: _selectedBinderId,
          );
          importedCount += item.quantity;
        } else {
          // Insert new VaultItem record scoped to target binder
          final newCardId = const Uuid().v4();
          final now = DateTime.now();
          await dao.insertItem(
            VaultItemsCompanion.insert(
              id: newCardId,
              name: item.name,
              setOrSeries: item.setCode ?? 'Imported',
              collectionType: 'mtg',
              quantity: drift.Value(item.quantity),
              imageUrl: '',
              condition: 'Near Mint',
              acquiredPrice: 0.0,
              currentMarketPrice: 0.0,
              acquiredDate: now,
              lastPriceUpdate: now,
              primaryBinderId: drift.Value(_selectedBinderId),
              dynamicData:
                  '{"collector_number": "${item.collectorNumber ?? '1'}"}',
            ),
          );
          importedCount += item.quantity;
        }
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Successfully imported $importedCount cards into ${_selectedBinderId == null ? "Vault" : "Binder"}!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Failed to import cards: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bindersAsync = ref.watch(bindersStreamProvider);
    final binders = bindersAsync.value ?? [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.file_download_outlined,
                        color: AppColors.accentCyan,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Import Cards to Vault',
                        style: AppTypography.heading1.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Import Mode Switcher
              Row(
                children: [
                  Expanded(
                    child: _ModeTabButton(
                      key: const Key('vault_import_tab_text'),
                      label: 'Paste Text List',
                      icon: Icons.format_list_bulleted_rounded,
                      isSelected: _importMode == VaultImportMode.textList,
                      onTap: () {
                        setState(() {
                          _importMode = VaultImportMode.textList;
                          _onTextChanged();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeTabButton(
                      key: const Key('vault_import_tab_link'),
                      label: 'Paste URL / Link',
                      icon: Icons.link_rounded,
                      isSelected: _importMode == VaultImportMode.link,
                      onTap: () {
                        setState(() {
                          _importMode = VaultImportMode.link;
                          _onTextChanged();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Destination Binder Dropdown
              Text(
                'DESTINATION BINDER',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    key: const Key('vault_import_binder_dropdown'),
                    value: _selectedBinderId,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceRaised,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.accentCyan),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                color: AppColors.accentCyan, size: 18),
                            SizedBox(width: 8),
                            Text('Unsorted (Main Vault)',
                                style: TextStyle(color: Colors.white, fontSize: 13.5)),
                          ],
                        ),
                      ),
                      ...binders.map((b) {
                        return DropdownMenuItem<String?>(
                          value: b.id,
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined,
                                  color: AppColors.accentAmber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_selectedBinderId != null && !binders.any((b) => b.id == _selectedBinderId))
                        DropdownMenuItem<String?>(
                          value: _selectedBinderId,
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined,
                                  color: AppColors.accentAmber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedBinderId!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (newBinderId) {
                      setState(() {
                        _selectedBinderId = newBinderId;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Input TextField
              Text(
                _importMode == VaultImportMode.textList
                    ? 'CARD LIST (e.g. "4 Lightning Bolt" or "1 Sol Ring")'
                    : 'PASTE LINK (Scryfall, Moxfield, MTGGoldfish)',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('vault_import_text_input'),
                controller: _inputController,
                maxLines: _importMode == VaultImportMode.textList ? 7 : 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: _importMode == VaultImportMode.textList
                      ? '4 Lightning Bolt\n2 Counterspell\n1 Birds of Paradise'
                      : 'https://scryfall.com/card/lea/1/black-lotus',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  contentPadding: const EdgeInsets.all(12),
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
              const SizedBox(height: 12),

              // Live Preview Counter
              if (_parsedPreview.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.accentCyan, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ready to import ${_parsedPreview.fold<int>(0, (s, i) => s + i.quantity)} total cards (${_parsedPreview.length} unique items)',
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Error / Status Message
              if (_statusMessage != null) ...[
                Text(
                  _statusMessage!,
                  style: const TextStyle(color: AppColors.accentRose, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],

              // Import Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('vault_import_submit_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing ? null : _handleImport,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textDark,
                          ),
                        )
                      : const Icon(Icons.file_download_done_rounded, size: 20),
                  label: Text(
                    _isProcessing
                        ? 'Importing Cards...'
                        : 'Import to ${_selectedBinderId == null ? "Vault" : "Binder"}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.15)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

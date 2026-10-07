// Copyright (c) 2026 Countr. All rights reserved.
// Deck Setup Wizard modal for blank deck creation and text decklist imports.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/deck_io_parser.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

enum DeckCreationMode {
  blank,
  importList,
}

/// Modal bottom sheet allowing users to set up a new deck by specifying
/// its name, format, and choosing between starting blank or importing a text list.
class DeckSetupWizardModal extends ConsumerStatefulWidget {
  final String initialTcgDomain;

  const DeckSetupWizardModal({
    super.key,
    this.initialTcgDomain = 'mtg',
  });

  /// Displays the [DeckSetupWizardModal] and returns the created [Deck] or null.
  static Future<Deck?> show(
    BuildContext context, {
    String initialTcgDomain = 'mtg',
  }) {
    return showModalBottomSheet<Deck>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeckSetupWizardModal(
        initialTcgDomain: initialTcgDomain,
      ),
    );
  }

  @override
  ConsumerState<DeckSetupWizardModal> createState() => _DeckSetupWizardModalState();
}

class _DeckSetupWizardModalState extends ConsumerState<DeckSetupWizardModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _importController;

  late String _selectedFormat;
  late String _selectedDomain;
  DeckCreationMode _creationMode = DeckCreationMode.blank;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _mtgFormats = [
    'Commander',
    'Modern',
    'Standard',
    'Pioneer',
    'Pauper',
    'Legacy',
    'Vintage',
  ];

  static const List<String> _pokemonFormats = [
    'Pokémon Standard',
    'Expanded',
  ];

  static const List<String> _lorcanaFormats = [
    'Disney Lorcana Core',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDomain = widget.initialTcgDomain == 'all' ? 'mtg' : widget.initialTcgDomain;

    if (_selectedDomain == 'pokemon') {
      _selectedFormat = _pokemonFormats.first;
    } else if (_selectedDomain == 'lorcana') {
      _selectedFormat = _lorcanaFormats.first;
    } else {
      _selectedFormat = _mtgFormats.first;
    }

    _nameController = TextEditingController();
    _importController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _importController.dispose();
    super.dispose();
  }

  List<String> get _currentFormats {
    if (_selectedDomain == 'pokemon') return _pokemonFormats;
    if (_selectedDomain == 'lorcana') return _lorcanaFormats;
    return _mtgFormats;
  }

  Future<void> _handleCreateDeck() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dao = ref.read(vaultDaoProvider);
      final deckName = _nameController.text.trim();

      // 1. Insert Deck & Active Version into SQLite
      final createdDeck = await dao.createDeck(
        deckName,
        format: _selectedFormat,
        tcgDomain: _selectedDomain,
      );

      // 2. If Import Mode selected, parse and insert cards
      if (_creationMode == DeckCreationMode.importList &&
          _importController.text.trim().isNotEmpty) {
        final rawText = _importController.text.trim();
        final parsedItems = DeckIOParser.parseList(rawText);

        final isCommander = _selectedFormat.toLowerCase().contains('commander') ||
            _selectedFormat.toLowerCase().contains('edh');

        for (int i = 0; i < parsedItems.length; i++) {
          final item = parsedItems[i];
          final searchMatches = await dao.searchCatalogCards(item.name, limit: 1);
          final String vaultItemId;

          if (searchMatches.isNotEmpty) {
            vaultItemId = searchMatches.first.id;
          } else {
            // Create a virtual / catalog vault item entry if not yet in vault
            final newCardId = const Uuid().v4();
            final cleanName = item.name.contains('//') ? item.name.split('//').first.trim() : item.name.trim();
            final scryfallArtUrl = _selectedDomain == 'mtg'
                ? CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'normal')
                : '';
            final scryfallArtCrop = _selectedDomain == 'mtg'
                ? CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'art_crop')
                : '';
            final dynDataMap = <String, dynamic>{
              'collector_number': item.collectorNumber ?? '1',
              if (_selectedDomain == 'mtg')
                'image_uris': {
                  'normal': scryfallArtUrl,
                  'art_crop': scryfallArtCrop,
                },
            };
            await dao.insertItem(
              VaultItemsCompanion.insert(
                id: newCardId,
                name: item.name,
                setOrSeries: item.setCode ?? 'Imported',
                collectionType: _selectedDomain,
                quantity: drift.Value(item.quantity),
                imageUrl: scryfallArtUrl,
                condition: 'Near Mint',
                acquiredPrice: 0.0,
                currentMarketPrice: 0.0,
                acquiredDate: DateTime.now(),
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode(dynDataMap),
              ),
            );
            vaultItemId = newCardId;
          }

          // If Commander format, auto-assign first parsed card as Commander
          final zone = (isCommander && i == 0) ? 'Commander' : 'Mainboard';

          await dao.addCardToDeck(
            createdDeck.id,
            vaultItemId,
            quantity: item.quantity,
            boardZone: zone,
          );
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(createdDeck);

      // Navigate to DeckBuilderScreen immediately
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => DeckBuilderScreen(deck: createdDeck),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to create deck: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Top Drag Handle
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

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Deck Setup',
                    style: AppTypography.heading1.copyWith(fontSize: 19),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Deck Name Input
              Text(
                'DECK NAME',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('deck_wizard_name_input'),
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Edgar Markov Aristocrats',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
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
                    borderSide: const BorderSide(color: AppColors.accentCyan),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a deck name';
                  }
                  if (val.trim().length > 60) {
                    return 'Deck name must be 60 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Format Dropdown
              Text(
                'FORMAT',
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
                  child: DropdownButton<String>(
                    key: const Key('deck_wizard_format_dropdown'),
                    value: _currentFormats.contains(_selectedFormat)
                        ? _selectedFormat
                        : _currentFormats.first,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceRaised,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentCyan),
                    items: _currentFormats.map((format) {
                      return DropdownMenuItem<String>(
                        value: format,
                        child: Text(
                          format,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (newFormat) {
                      if (newFormat != null) {
                        setState(() {
                          _selectedFormat = newFormat;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Creation Mode Selector
              Text(
                'CREATION MODE',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                key: const Key('deck_wizard_mode_selector'),
                children: [
                  Expanded(
                    child: _ModeOptionButton(
                      key: const Key('deck_wizard_mode_blank'),
                      title: 'Create Blank',
                      subtitle: 'Start with an empty deck',
                      icon: Icons.note_add_outlined,
                      isSelected: _creationMode == DeckCreationMode.blank,
                      onTap: () => setState(() => _creationMode = DeckCreationMode.blank),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeOptionButton(
                      key: const Key('deck_wizard_mode_import'),
                      title: 'Import Decklist',
                      subtitle: 'Paste cards or decklist text',
                      icon: Icons.file_upload_outlined,
                      isSelected: _creationMode == DeckCreationMode.importList,
                      onTap: () => setState(() => _creationMode = DeckCreationMode.importList),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Import Text Area (if import mode active)
              if (_creationMode == DeckCreationMode.importList) ...[
                Text(
                  'PASTE DECKLIST (e.g. "1 Sol Ring" or "4 Lightning Bolt")',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentCyan,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('deck_wizard_import_text_input'),
                  controller: _importController,
                  maxLines: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: '1 Edgar Markov\n1 Sol Ring\n1 Arcane Signet\n1 Command Tower',
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
                const SizedBox(height: 16),
              ],

              // Error Message
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.accentRose, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('deck_wizard_create_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleCreateDeck,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textDark,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(
                    _creationMode == DeckCreationMode.importList
                        ? 'Import & Build Deck'
                        : 'Create & Open Deck',
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

class _ModeOptionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.12)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

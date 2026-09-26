import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Candidate print representation for SwitchPrintingModal.
class CardPrintCandidate {
  final String setCode;
  final String setName;
  final String collectorNumber;
  final String imageUrl;
  final String? artCropUrl;
  final double marketPrice;
  final String rarity;
  final List<String> finishes;
  final List<String> frameEffects;
  final String? releasedAt;
  final Map<String, dynamic> rawData;

  CardPrintCandidate({
    required this.setCode,
    required this.setName,
    required this.collectorNumber,
    required this.imageUrl,
    this.artCropUrl,
    required this.marketPrice,
    required this.rarity,
    required this.finishes,
    required this.frameEffects,
    this.releasedAt,
    required this.rawData,
  });

  factory CardPrintCandidate.fromScryfall(Map<String, dynamic> json) {
    final imageUris = json['image_uris'] as Map<String, dynamic>? ?? {};
    final prices = json['prices'] as Map<String, dynamic>? ?? {};
    final usd = double.tryParse(prices['usd']?.toString() ?? '') ??
        double.tryParse(prices['usd_foil']?.toString() ?? '') ??
        0.0;

    return CardPrintCandidate(
      setCode: (json['set']?.toString() ?? '').toLowerCase(),
      setName: json['set_name']?.toString() ?? json['set']?.toString() ?? 'Unknown Set',
      collectorNumber: json['collector_number']?.toString() ?? '',
      imageUrl: (imageUris['normal'] ?? imageUris['small'] ?? '') as String,
      artCropUrl: imageUris['art_crop'] as String?,
      marketPrice: usd,
      rarity: json['rarity']?.toString() ?? 'normal',
      finishes: (json['finishes'] as List?)?.map((e) => e.toString()).toList() ?? ['nonfoil'],
      frameEffects: (json['frame_effects'] as List?)?.map((e) => e.toString()).toList() ?? [],
      releasedAt: json['released_at']?.toString(),
      rawData: json,
    );
  }

  factory CardPrintCandidate.fromVaultItem(VaultItem item) {
    String setCode = '';
    String collectorNum = '';
    String? artCrop;
    List<String> finishes = ['nonfoil'];
    List<String> frameEffects = [];

    if (item.dynamicData.isNotEmpty) {
      try {
        final d = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        setCode = d['set_code']?.toString() ?? d['set']?.toString() ?? '';
        collectorNum = d['collector_number']?.toString() ?? '';
        final uris = d['image_uris'] as Map<String, dynamic>?;
        if (uris != null) artCrop = uris['art_crop'] as String?;
        if (d['finishes'] is List) {
          finishes = (d['finishes'] as List).map((e) => e.toString()).toList();
        }
        if (d['frame_effects'] is List) {
          frameEffects = (d['frame_effects'] as List).map((e) => e.toString()).toList();
        }
      } catch (e, stackTrace) {
        debugPrint('[CardPrintCandidate.fromVaultItem] Failed parsing dynamicData: $e\n$stackTrace');
      }
    }

    return CardPrintCandidate(
      setCode: setCode.isNotEmpty ? setCode : item.setOrSeries.toLowerCase(),
      setName: item.setOrSeries,
      collectorNumber: collectorNum,
      imageUrl: item.imageUrl,
      artCropUrl: artCrop,
      marketPrice: item.currentMarketPrice,
      rarity: 'normal',
      finishes: finishes,
      frameEffects: frameEffects,
      rawData: {},
    );
  }
}

/// Modal allowing users to modify a card's set code, treatment, collector number,
/// and art crop without deleting or rescanning the card in Vault / Collection Detail.
class SwitchPrintingModal extends ConsumerStatefulWidget {
  final VaultItem item;
  final void Function(VaultItem updatedItem)? onUpdated;

  const SwitchPrintingModal({
    super.key,
    required this.item,
    this.onUpdated,
  });

  static Future<VaultItem?> show(
    BuildContext context,
    VaultItem item, {
    void Function(VaultItem updatedItem)? onUpdated,
  }) {
    return showModalBottomSheet<VaultItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => SwitchPrintingModal(
        item: item,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  ConsumerState<SwitchPrintingModal> createState() => _SwitchPrintingModalState();
}

class _SwitchPrintingModalState extends ConsumerState<SwitchPrintingModal> {
  bool _isLoading = true;
  List<CardPrintCandidate> _candidates = [];
  CardPrintCandidate? _selectedCandidate;
  String _selectedTreatment = 'Standard';
  bool _isSaving = false;

  late TextEditingController _customCollectorNumberController;
  late TextEditingController _customSetController;

  static const _treatmentOptions = [
    'Standard',
    'Foil',
    'Etched Foil',
    'Showcase',
    'Borderless',
    'Extended Art',
    'Retro Frame',
  ];

  @override
  void initState() {
    super.initState();
    _customCollectorNumberController = TextEditingController();
    _customSetController = TextEditingController();

    _initializeCandidateAndLoad();
  }

  @override
  void dispose() {
    _customCollectorNumberController.dispose();
    _customSetController.dispose();
    super.dispose();
  }

  Future<void> _initializeCandidateAndLoad() async {
    final currentCandidate = CardPrintCandidate.fromVaultItem(widget.item);
    _selectedCandidate = currentCandidate;
    _customCollectorNumberController.text = currentCandidate.collectorNumber;
    _customSetController.text = currentCandidate.setCode.toUpperCase();

    // 1. Load local catalog prints
    final dao = ref.read(vaultDaoProvider);
    final localItems = await dao.getCatalogPrintings(widget.item.name);
    final list = localItems.map((e) => CardPrintCandidate.fromVaultItem(e)).toList();

    if (mounted) {
      setState(() {
        _candidates = list.isNotEmpty ? list : [currentCandidate];
        _isLoading = false;
      });
    }

    // 2. Fetch all prints from Scryfall API asynchronously
    try {
      final scryfall = ref.read(scryfallServiceProvider);
      String? oracleId;
      if (widget.item.dynamicData.isNotEmpty) {
        try {
          final dyn = jsonDecode(widget.item.dynamicData) as Map<String, dynamic>;
          oracleId = dyn['oracle_id'] as String?;
        } catch (e, stackTrace) {
          debugPrint('[SwitchPrintingModal._initializeCandidateAndLoad] Failed parsing oracle_id: $e\n$stackTrace');
        }
      }

      final rawPrints = await scryfall.fetchCardPrintings(
        cardName: widget.item.name,
        oracleId: oracleId,
      );
      if (rawPrints != null && rawPrints.isNotEmpty && mounted) {
        final onlineCandidates =
            rawPrints.map((p) => CardPrintCandidate.fromScryfall(p)).toList();

        // Cache newly discovered printings in local SQLite dictionary
        try {
          final companions =
              rawPrints.map((p) => mapScryfallCardToCompanion(p)).toList();
          await dao.insertDictionaryChunked(companions);
        } catch (e, stackTrace) {
          debugPrint('[SwitchPrintingModal._initializeCandidateAndLoad] Failed caching companions: $e\n$stackTrace');
        }

        if (mounted) {
          setState(() {
            _candidates = onlineCandidates;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SwitchPrintingModal._initializeCandidateAndLoad] Failed fetching printings: $e\n$stackTrace');
    }
  }

  Future<void> _applySwitchPrinting() async {
    if (_selectedCandidate == null || _isSaving) return;

    setState(() => _isSaving = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      final updatedItem = await dao.switchCardPrinting(
        id: widget.item.id,
        setCode: _customSetController.text.trim().toLowerCase(),
        setName: _selectedCandidate!.setName,
        collectorNumber: _customCollectorNumberController.text.trim(),
        imageUrl: _selectedCandidate!.imageUrl,
        artCropUrl: _selectedCandidate!.artCropUrl,
        marketPrice: _selectedCandidate!.marketPrice,
        treatment: _selectedTreatment,
        extraDynamicData: _selectedCandidate!.rawData,
      );

      widget.onUpdated?.call(updatedItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${updatedItem.setOrSeries} printing!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentEmerald,
          ),
        );
        Navigator.of(context).pop(updatedItem);
      }
    } catch (e, stackTrace) {
      debugPrint('[SwitchPrintingModal._applySwitchPrinting] Failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating printing: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _isPrivacyMode {
    final hasScope =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
            context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
    if (hasScope) {
      try {
        return ref.watch(privacyModeProvider);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacyMode = _isPrivacyMode;
    final active = _selectedCandidate;
    final isPriceDiff = active != null &&
        (active.marketPrice - widget.item.currentMarketPrice).abs() > 0.01;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.60,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

              // Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.style_rounded, color: AppColors.accentCyan, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Switch Printing / Edition', style: AppTypography.heading2),
                          Text(
                            widget.item.name,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Comparison Preview Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          if (active?.artCropUrl != null && active!.artCropUrl!.isNotEmpty)
                            CountrCachedImage(
                              imageUrl: active.artCropUrl!,
                              width: 80,
                              height: 58,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                              errorWidget: _buildPlaceholder(),
                            )
                          else if (active?.imageUrl != null && active!.imageUrl.isNotEmpty)
                            CountrCachedImage(
                              imageUrl: active.imageUrl,
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                              errorWidget: _buildPlaceholder(),
                            )
                          else
                            _buildPlaceholder(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PREVIEW PRINTING',
                                  style: TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  active?.setName ?? widget.item.setOrSeries,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      isPrivacyMode
                                          ? '****'
                                          : (active != null && active.marketPrice > 0
                                              ? '\$${active.marketPrice.toStringAsFixed(2)}'
                                              : '—'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentEmerald, fontSize: 13),
                                    ),
                                    if (isPriceDiff) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        isPrivacyMode
                                            ? '(Was ****)'
                                            : '(Was \$${widget.item.currentMarketPrice.toStringAsFixed(2)})',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Available Editions Carousel / Grid Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Printings (${_candidates.length})',
                          style: AppTypography.heading2.copyWith(fontSize: 14),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Printings Horizontal Carousel
                    SizedBox(
                      height: 155,
                      child: _candidates.isEmpty && !_isLoading
                          ? const Center(
                              child: Text(
                                'No other editions found.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _candidates.length,
                              itemBuilder: (context, index) {
                                final print = _candidates[index];
                                final isSelected = active?.setCode == print.setCode &&
                                    active?.collectorNumber == print.collectorNumber;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCandidate = print;
                                      _customSetController.text = print.setCode.toUpperCase();
                                      _customCollectorNumberController.text = print.collectorNumber;
                                    });
                                  },
                                  child: Container(
                                    width: 105,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.accentCyan.withValues(alpha: 0.15)
                                          : AppColors.surfaceRaised,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorderSubtle,
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: SizedBox(
                                            height: 80,
                                            width: 60,
                                            child: print.imageUrl.isNotEmpty
                                                ? CountrCachedImage(
                                                    imageUrl: print.imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorWidget: _buildPlaceholder(),
                                                  )
                                                : _buildPlaceholder(),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          print.setCode.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isSelected ? AppColors.accentCyan : Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          isPrivacyMode
                                              ? '#${print.collectorNumber} • ****'
                                              : '#${print.collectorNumber} • \$${print.marketPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Treatment Selector (Foil, Showcase, Etched, etc.)
                    const Text('Finish & Treatment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _treatmentOptions.map((treatment) {
                        final isSelected = _selectedTreatment == treatment;
                        return ChoiceChip(
                          label: Text(treatment),
                          selected: isSelected,
                          selectedColor: AppColors.accentCyan.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surfaceRaised,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedTreatment = treatment);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Fine-Tuning: Set Code & Collector Number Inputs
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Set Code', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _customSetController,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surfaceRaised,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Collector #', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _customCollectorNumberController,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surfaceRaised,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pinned Bottom Button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('apply_switch_printing_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.check_rounded),
                      label: const Text('Apply Printing Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: !_isSaving ? _applySwitchPrinting : null,
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceRaised,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 24),
      ),
    );
  }
}

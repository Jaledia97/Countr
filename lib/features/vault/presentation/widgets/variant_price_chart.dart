import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';

/// ManaBox-style horizontal scrolling list displaying all available card printings,
/// art variants, finishes, and current market prices with interactive preview/switching.
class VariantPriceChart extends ConsumerStatefulWidget {
  final VaultItem item;
  final ValueChanged<CardPrintCandidate>? onPrintingSelected;
  final ValueChanged<VaultItem>? onPrintingChanged;
  final List<CardPrintCandidate>? initialVariants;
  final bool enableOnlineFetch;
  final bool? isPrivacyMode;

  const VariantPriceChart({
    super.key,
    required this.item,
    this.onPrintingSelected,
    this.onPrintingChanged,
    this.initialVariants,
    this.enableOnlineFetch = true,
    this.isPrivacyMode,
  });

  @override
  ConsumerState<VariantPriceChart> createState() => _VariantPriceChartState();
}

class _VariantPriceChartState extends ConsumerState<VariantPriceChart> {
  List<CardPrintCandidate> _variants = [];
  CardPrintCandidate? _selectedVariant;
  bool _isLoading = false;
  bool _isSwitching = false;

  bool get _isPrivacyMode =>
      widget.isPrivacyMode ??
      (context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
              context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null
          ? ref.watch(privacyModeProvider)
          : false);

  @override
  void initState() {
    super.initState();
    _initializeVariants();
  }

  @override
  void didUpdateWidget(covariant VariantPriceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.setOrSeries != widget.item.setOrSeries ||
        oldWidget.initialVariants != widget.initialVariants) {
      _initializeVariants();
    }
  }

  bool _matchesItem(CardPrintCandidate candidate, VaultItem item) {
    final candidateSet = candidate.setCode.trim().toLowerCase();
    String itemSet = '';
    String itemCollector = '';

    if (item.dynamicData.isNotEmpty) {
      try {
        final d = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        itemSet = (d['set_code'] ?? d['set'] ?? '').toString().trim().toLowerCase();
        itemCollector = (d['collector_number'] ?? '').toString().trim();
      } catch (e, stackTrace) {
        debugPrint('[VariantPriceChart._matchesItem] Failed parsing dynamicData: $e\n$stackTrace');
      }
    }

    if (itemSet.isEmpty) {
      itemSet = item.setOrSeries.trim().toLowerCase();
    }

    if (candidateSet == itemSet) {
      if (itemCollector.isNotEmpty && candidate.collectorNumber.isNotEmpty) {
        return candidate.collectorNumber.trim() == itemCollector;
      }
      return true;
    }
    return false;
  }

  Future<void> _initializeVariants() async {
    if (widget.initialVariants != null) {
      setState(() {
        _variants = List.from(widget.initialVariants!);
        _selectedVariant = _variants.isNotEmpty
            ? _variants.firstWhere(
                (c) => _matchesItem(c, widget.item),
                orElse: () => _variants.first,
              )
            : null;
      });
      return;
    }

    final currentCandidate = CardPrintCandidate.fromVaultItem(widget.item);
    setState(() {
      _variants = [currentCandidate];
      _selectedVariant = currentCandidate;
      _isLoading = true;
    });

    // 1. Query local SQLite catalog printings on mount
    try {
      final dao = ref.read(vaultDaoProvider);
      final localItems = await dao.getCatalogPrintings(widget.item.name);
      if (localItems.isNotEmpty && mounted) {
        final list = localItems.map((e) => CardPrintCandidate.fromVaultItem(e)).toList();
        final Map<String, CardPrintCandidate> map = {};
        for (final c in list) {
          final key = '${c.setCode.toLowerCase()}_${c.collectorNumber}';
          map[key] = c;
        }
        // Ensure current is present
        final currentKey = '${currentCandidate.setCode.toLowerCase()}_${currentCandidate.collectorNumber}';
        map[currentKey] = currentCandidate;

        setState(() {
          _variants = map.values.toList();
          _selectedVariant = _variants.firstWhere(
            (c) => _matchesItem(c, widget.item),
            orElse: () => currentCandidate,
          );
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[VariantPriceChart._initializeVariants] Failed loading local catalog printings: $e\n$stackTrace');
    }

    // 2. Concurrently fetch Scryfall printings (with offline/test graceful fallback)
    if (widget.enableOnlineFetch) {
      try {
        final scryfall = ref.read(scryfallServiceProvider);
        String? oracleId;
        if (widget.item.dynamicData.isNotEmpty) {
          try {
            final dyn = jsonDecode(widget.item.dynamicData) as Map<String, dynamic>;
            oracleId = dyn['oracle_id'] as String?;
          } catch (e, stackTrace) {
            debugPrint('[VariantPriceChart._initializeVariants] Failed parsing oracle_id: $e\n$stackTrace');
          }
        }

        final rawPrints = await scryfall.fetchCardPrintings(
          cardName: widget.item.name,
          oracleId: oracleId,
        );

        if (rawPrints != null && rawPrints.isNotEmpty && mounted) {
          final onlineCandidates = rawPrints.map((p) => CardPrintCandidate.fromScryfall(p)).toList();

          // Cache newly discovered printings in local SQLite dictionary
          try {
            final dao = ref.read(vaultDaoProvider);
            final companions = rawPrints.map((p) => mapScryfallCardToCompanion(p)).toList();
            await dao.insertDictionaryChunked(companions);
          } catch (e, stackTrace) {
            debugPrint('[VariantPriceChart._initializeVariants] Failed caching printings: $e\n$stackTrace');
          }

          if (mounted) {
            setState(() {
              _variants = onlineCandidates;
              _selectedVariant = _variants.firstWhere(
                (c) => _matchesItem(c, widget.item),
                orElse: () => onlineCandidates.first,
              );
              _isLoading = false;
            });
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (e, stackTrace) {
        debugPrint('[VariantPriceChart._initializeVariants] Failed fetching online printings: $e\n$stackTrace');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applySwitchPrinting(CardPrintCandidate candidate) async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);

    try {
      final dao = ref.read(vaultDaoProvider);
      final updatedItem = await dao.switchCardPrinting(
        id: widget.item.id,
        setCode: candidate.setCode.toLowerCase(),
        setName: candidate.setName,
        collectorNumber: candidate.collectorNumber,
        imageUrl: candidate.imageUrl,
        artCropUrl: candidate.artCropUrl,
        marketPrice: candidate.marketPrice,
        treatment: candidate.finishes.contains('etched')
            ? 'Etched Foil'
            : (candidate.finishes.contains('foil') ? 'Foil' : 'Standard'),
        extraDynamicData: candidate.rawData,
      );

      widget.onPrintingChanged?.call(updatedItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${candidate.setName} (#${candidate.collectorNumber})'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentEmerald,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[VariantPriceChart._applySwitchPrinting] Failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating printing: $e'),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSwitch = widget.item.id.isNotEmpty &&
        widget.item.quantity > 0 &&
        _selectedVariant != null &&
        !_matchesItem(_selectedVariant!, widget.item);

    return Column(
      key: const Key('section_variant_price_chart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row with wrap-friendly layout
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.style_rounded, size: 16, color: AppColors.accentCyan),
                  const SizedBox(width: 8),
                  Text(
                    'Versions & Printings (${_variants.length})',
                    style: AppTypography.heading2.copyWith(fontSize: 14),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canSwitch)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: OutlinedButton.icon(
                  key: const Key('button_apply_switch_printing'),
                  icon: _isSwitching
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.accentCyan,
                          ),
                        )
                      : const Icon(Icons.sync_alt, size: 13, color: AppColors.accentCyan),
                  label: const Text(
                    'Set as Active',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.accentCyan),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  onPressed: _isSwitching ? null : () => _applySwitchPrinting(_selectedVariant!),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // ManaBox-style horizontal scrolling list with explicit bounded height (~165-175px)
        SizedBox(
          height: 172,
          child: _variants.isEmpty
              ? Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Text(
                    'No alternative printings found.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  key: const Key('variant_price_chart_list'),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _variants.length,
                  itemBuilder: (context, index) {
                    final variant = _variants[index];
                    final isSelected = _selectedVariant != null &&
                        _selectedVariant!.setCode.toLowerCase() == variant.setCode.toLowerCase() &&
                        _selectedVariant!.collectorNumber == variant.collectorNumber;
                    final isActivePrinting = _matchesItem(variant, widget.item);

                    return _buildVariantCard(
                      context,
                      variant,
                      isSelected: isSelected,
                      isActivePrinting: isActivePrinting,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVariantCard(
    BuildContext context,
    CardPrintCandidate variant, {
    required bool isSelected,
    required bool isActivePrinting,
  }) {
    // Determine treatment/finish label
    String finishLabel = 'Non-foil';
    Color finishColor = AppColors.textSecondary;
    Color finishBg = AppColors.surfaceHighlight;

    if (variant.finishes.contains('etched')) {
      finishLabel = 'Etched';
      finishColor = AppColors.accentVioletLight;
      finishBg = AppColors.accentViolet.withValues(alpha: 0.18);
    } else if (variant.finishes.contains('foil')) {
      finishLabel = 'Foil';
      finishColor = AppColors.accentAmber;
      finishBg = AppColors.accentAmber.withValues(alpha: 0.18);
    }

    final cardKey = Key('variant_card_${variant.setCode}_${variant.collectorNumber}');

    return GestureDetector(
      key: cardKey,
      onTap: () {
        setState(() {
          _selectedVariant = variant;
        });
        widget.onPrintingSelected?.call(variant);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 114,
        margin: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.14)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accentCyan
                : (isActivePrinting ? AppColors.accentAmber : AppColors.surfaceBorder),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Art crop thumbnail (ClipRRect with rounded top corners)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: SizedBox(
                height: 68,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnailImage(variant),
                    if (isActivePrinting)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.accentAmber, width: 0.8),
                          ),
                          child: const Text(
                            'OWNED',
                            style: TextStyle(
                              color: AppColors.accentAmber,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Card metadata container
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 2. Set Code badge & Collector number
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentCyan.withValues(alpha: 0.6)
                                    : AppColors.surfaceBorderSubtle,
                              ),
                            ),
                            child: Text(
                              variant.setCode.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${variant.collectorNumber}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Finish / treatment pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: finishBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          finishLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: finishColor,
                          ),
                        ),
                      ),
                    ),

                    // 4. Current Market Price
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isPrivacyMode
                            ? '****'
                            : (variant.marketPrice > 0
                                ? '\$${variant.marketPrice.toStringAsFixed(2)}'
                                : '—'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailImage(CardPrintCandidate variant) {
    final url = variant.artCropUrl ?? variant.imageUrl;
    if (url.isEmpty) {
      return Container(
        color: AppColors.surfaceHighlight,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 22, color: AppColors.textMuted),
      );
    }

    return CountrCachedImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: Container(
        color: AppColors.surfaceHighlight,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 22, color: AppColors.textMuted),
      ),
    );
  }
}

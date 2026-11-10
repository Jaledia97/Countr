import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';

/// Modal bottom sheet for exploring all visual Variants and historical Set Printings.
/// Lazy-loads data on demand when opened; does not perform network or DB queries beforehand.
class VersionsAndPrintingsModal extends ConsumerStatefulWidget {
  final VaultItem item;
  final bool? isPrivacyMode;
  final bool enableOnlineFetch;
  final ValueChanged<VaultItem>? onPrintingChanged;

  const VersionsAndPrintingsModal({
    super.key,
    required this.item,
    this.isPrivacyMode,
    this.enableOnlineFetch = true,
    this.onPrintingChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required VaultItem item,
    bool? isPrivacyMode,
    bool enableOnlineFetch = true,
    ValueChanged<VaultItem>? onPrintingChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VersionsAndPrintingsModal(
        item: item,
        isPrivacyMode: isPrivacyMode,
        enableOnlineFetch: enableOnlineFetch,
        onPrintingChanged: onPrintingChanged,
      ),
    );
  }

  @override
  ConsumerState<VersionsAndPrintingsModal> createState() =>
      _VersionsAndPrintingsModalState();
}

class _VersionsAndPrintingsModalState
    extends ConsumerState<VersionsAndPrintingsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CardPrintCandidate> _variants = [];
  bool _isLoading = true;

  bool get _isPrivacyMode =>
      widget.isPrivacyMode ??
      (context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
              context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null
          ? ref.watch(privacyModeProvider)
          : false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVariants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    setState(() => _isLoading = true);
    final dao = ref.read(vaultDaoProvider);
    final scryfall = ref.read(scryfallServiceProvider);

    try {
      final localItems = await dao.getCatalogPrintings(widget.item.name);
      List<CardPrintCandidate> candidates =
          localItems.map((e) => CardPrintCandidate.fromVaultItem(e)).toList();

      if (widget.enableOnlineFetch) {
        String? oracleId;
        if (widget.item.dynamicData.isNotEmpty) {
          try {
            final d = jsonDecode(widget.item.dynamicData) as Map<String, dynamic>;
            oracleId = d['oracle_id']?.toString();
          } catch (_) {}
        }
        final rawPrints = await scryfall.fetchCardPrintings(
          cardName: widget.item.name,
          oracleId: oracleId,
        );
        if (rawPrints != null && rawPrints.isNotEmpty) {
          final onlineCandidates =
              rawPrints.map((j) => CardPrintCandidate.fromScryfall(j)).toList();
          final existingKeys = candidates
              .map((c) => '${c.setCode}_${c.collectorNumber}'.toLowerCase())
              .toSet();
          for (final oc in onlineCandidates) {
            final key = '${oc.setCode}_${oc.collectorNumber}'.toLowerCase();
            if (!existingKeys.contains(key)) {
              candidates.add(oc);
              existingKeys.add(key);
            }
          }
        }
      }

      if (candidates.isEmpty) {
        candidates = [CardPrintCandidate.fromVaultItem(widget.item)];
      }

      if (mounted) {
        setState(() {
          _variants = candidates;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[VersionsAndPrintingsModal] Error loading printings: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          if (_variants.isEmpty) {
            _variants = [CardPrintCandidate.fromVaultItem(widget.item)];
          }
          _isLoading = false;
        });
      }
    }
  }

  VaultItem _synthesizeVaultItem(CardPrintCandidate candidate) {
    Map<String, dynamic> merged = Map<String, dynamic>.from(candidate.rawData);
    merged['collector_number'] = candidate.collectorNumber;
    merged['set'] = candidate.setCode.toLowerCase();
    merged['set_name'] = candidate.setName;
    merged['finishes'] = candidate.finishes;
    merged['prices'] = {'usd': candidate.marketPrice};

    return VaultItem(
      id: candidate.rawData['id']?.toString() ??
          '${widget.item.name}_${candidate.setCode}_${candidate.collectorNumber}',
      collectionType: widget.item.collectionType,
      name: widget.item.name,
      setOrSeries: candidate.setName,
      imageUrl: candidate.imageUrl.isNotEmpty
          ? candidate.imageUrl
          : widget.item.imageUrl,
      acquiredPrice: candidate.marketPrice,
      acquiredDate: DateTime.now(),
      quantity: 0,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: candidate.marketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode(merged),
    );
  }

  void _handleCandidateTap(CardPrintCandidate candidate) {
    String? currentCollectorNumber;
    String? currentSet;
    if (widget.item.dynamicData.isNotEmpty) {
      try {
        final d = jsonDecode(widget.item.dynamicData) as Map<String, dynamic>;
        currentCollectorNumber = d['collector_number']?.toString();
        currentSet = d['set']?.toString();
      } catch (_) {}
    }
    final isSamePrinting = (candidate.setCode.toLowerCase() == (currentSet ?? widget.item.setOrSeries).toLowerCase()) &&
        (candidate.collectorNumber == (currentCollectorNumber ?? ''));
    if (isSamePrinting) {
      Navigator.of(context).pop();
      return;
    }
    final synthesized = _synthesizeVaultItem(candidate);
    widget.onPrintingChanged?.call(synthesized);
    CardDetailSheet.show(context, synthesized);
  }

  List<CardPrintCandidate> get _versionVariants {
    final filtered = _variants.where((c) {
      final borderless = c.rawData['border_color'] == 'borderless';
      final retro = c.rawData['frame'] == '1993' || c.rawData['frame'] == '1997';
      final fullArt = c.rawData['full_art'] == true;
      final hasEffects = c.frameEffects.isNotEmpty;
      final promoTypes = c.rawData['promo_types'];
      final hasPromo = promoTypes is List && promoTypes.isNotEmpty;
      return borderless || retro || fullArt || hasEffects || hasPromo;
    }).toList();

    return filtered.isNotEmpty ? filtered : _variants;
  }

  String _deriveVariantBadge(CardPrintCandidate c) {
    if (c.rawData['border_color'] == 'borderless') return 'Borderless';
    if (c.frameEffects.contains('showcase')) return 'Showcase';
    if (c.frameEffects.contains('extendedart')) return 'Extended Art';
    if (c.rawData['frame'] == '1993' || c.rawData['frame'] == '1997') return 'Retro Frame';
    if (c.rawData['full_art'] == true) return 'Full Art';
    if (c.frameEffects.isNotEmpty) {
      return c.frameEffects.first[0].toUpperCase() + c.frameEffects.first.substring(1);
    }
    return 'Standard';
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'mythic':
        return AppColors.accentAmber;
      case 'rare':
        return AppColors.accentGold;
      case 'uncommon':
        return AppColors.accentCyan;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row with Upper-Left Back Button (Feature 27)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('versions_printings_back_button'),
                    tooltip: 'Back to Card Details',
                    icon: const Icon(Icons.arrow_back, color: AppColors.accentCyan, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Versions & Printings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar: Versions & Printings
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceBorder, width: 1.0),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accentCyan,
                labelColor: AppColors.accentCyan,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.auto_awesome, size: 16),
                    text: 'Versions',
                  ),
                  Tab(
                    icon: Icon(Icons.style, size: 16),
                    text: 'Printings',
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accentCyan),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVersionsTab(),
                        _buildPrintingsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsTab() {
    final versions = _versionVariants;

    if (versions.isEmpty) {
      return const Center(
        child: Text(
          'No alternative versions found.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final c = versions[index];
        final cardKey =
            'variant_card_${c.setCode.toLowerCase()}_${c.collectorNumber.toLowerCase()}';
        final priceStr = _isPrivacyMode
            ? '****'
            : (c.marketPrice > 0
                ? '\$${c.marketPrice.toStringAsFixed(2)}'
                : 'Unlisted');
        final badge = _deriveVariantBadge(c);

        return GestureDetector(
          key: Key(cardKey),
          onTap: () => _handleCandidateTap(c),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: c.imageUrl.isNotEmpty
                        ? CountrCachedImage(
                            imageUrl: c.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 320,
                          )
                        : Container(
                            color: AppColors.surfaceHighlight,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: AppColors.textMuted),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${c.setCode.toUpperCase()} #${c.collectorNumber}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            priceStr,
                            style: const TextStyle(
                              color: AppColors.accentEmerald,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrintingsTab() {
    if (_variants.isEmpty) {
      return const Center(
        child: Text(
          'No alternative printings found.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _variants.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.surfaceBorder,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final c = _variants[index];
        final cardKey =
            'variant_card_${c.setCode.toLowerCase()}_${c.collectorNumber.toLowerCase()}';
        final priceStr = _isPrivacyMode
            ? '****'
            : (c.marketPrice > 0
                ? '\$${c.marketPrice.toStringAsFixed(2)}'
                : 'Unlisted');
        final rarityColor = _getRarityColor(c.rarity);
        final lang = (c.rawData['lang']?.toString() ?? 'EN').toUpperCase();

        return InkWell(
          key: Key(cardKey),
          onTap: () => _handleCandidateTap(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Row(
              children: [
                // Set Badge
                Container(
                  width: 44,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    c.setCode.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Set Name, Collector #, Language, Rarity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.setName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '#${c.collectorNumber}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              c.rarity.toUpperCase(),
                              style: TextStyle(
                                color: rarityColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              lang,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Price Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priceStr,
                      style: const TextStyle(
                        color: AppColors.accentEmerald,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Market',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}

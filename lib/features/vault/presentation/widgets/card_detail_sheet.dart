import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/domain/models/scryfall_ruling.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/edit_card_modal.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

/// Draggable modal bottom sheet displaying full card breakdown, oracle rules text,
/// community use cases, deck history, and collection portfolio analytics.
class CardDetailSheet extends ConsumerStatefulWidget {
  final VaultItem item;

  const CardDetailSheet({super.key, required this.item});

  /// Opens the CardDetailSheet inside a draggable scrollable modal bottom sheet.
  static Future<void> show(BuildContext context, VaultItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => CardDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends ConsumerState<CardDetailSheet>
    with SingleTickerProviderStateMixin {
  late TextEditingController _notesController;
  late TextEditingController _deckTagController;
  late VaultItem _currentItem;
  Map<String, dynamic> _dynamicData = {};
  List<String> _deckHistory = [];
  bool _isSavingNotes = false;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isFlipped = false;

  List<ScryfallRuling> _cachedRulings = [];
  bool _isLoadingRulings = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _notesController = TextEditingController(text: _currentItem.personalNotes ?? '');
    _deckTagController = TextEditingController();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
    _parseDynamicData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndCacheRulings();
      _healMissingMultiFaceData();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _deckTagController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CardDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.dynamicData != widget.item.dynamicData ||
        (_cachedRulings.isEmpty && !_dynamicData.containsKey('cached_rulings'))) {
      _currentItem = widget.item;
      _parseDynamicData();
      _isFlipped = false;
      _flipController.reset();
      _fetchAndCacheRulings();
      _healMissingMultiFaceData();
    }
  }

  void _parseDynamicData() {
    if (_currentItem.dynamicData.isNotEmpty) {
      try {
        _dynamicData = jsonDecode(_currentItem.dynamicData) as Map<String, dynamic>;
        final rawDecks = _dynamicData['deck_history'];
        if (rawDecks is List) {
          _deckHistory = rawDecks.map((e) => e.toString()).toList();
        }
        final rawCached = _dynamicData['cached_rulings'];
        if (rawCached is List) {
          _cachedRulings = rawCached.map((e) {
            if (e is Map<String, dynamic>) {
              return ScryfallRuling.fromJson(e);
            } else if (e is Map) {
              return ScryfallRuling.fromJson(Map<String, dynamic>.from(e));
            }
            return ScryfallRuling(publishedAt: '', comment: e.toString());
          }).toList();
        }
      } catch (_) {
        _dynamicData = {};
      }
    }
  }

  List<Map<String, dynamic>> _getCardFaces() {
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      return faces
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    final hasSlash =
        _currentItem.name.contains(' // ') || _currentItem.name.contains('//');
    if (hasSlash) {
      final sep = _currentItem.name.contains(' // ') ? ' // ' : '//';
      final names = _currentItem.name.split(sep);
      final oracle = _dynamicData['oracle_text']?.toString() ?? '';
      final oracleSep = oracle.contains(' // ')
          ? ' // '
          : (oracle.contains('//') ? '//' : null);
      final oracles =
          oracleSep != null ? oracle.split(oracleSep) : [oracle, ''];
      return [
        {'name': names[0].trim(), 'oracle_text': oracles[0].trim()},
        {
          'name': names.length > 1 ? names[1].trim() : '',
          'oracle_text': oracles.length > 1 ? oracles[1].trim() : '',
        },
      ];
    }
    return const [];
  }

  bool _isAdventureCard() {
    final layout = _dynamicData['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'adventure') return true;

    final typeLine = _dynamicData['type_line']?.toString().toLowerCase() ?? '';
    if (typeLine.contains('adventure')) return true;

    final faces = _getCardFaces();
    for (final face in faces) {
      final faceType = face['type_line']?.toString().toLowerCase() ?? '';
      if (faceType.contains('adventure')) return true;
    }

    final rawJson = _currentItem.dynamicData.toLowerCase();
    if (rawJson.contains('"layout":"adventure"') ||
        rawJson.contains('"layout": "adventure"') ||
        rawJson.contains('instant — adventure') ||
        rawJson.contains('sorcery — adventure') ||
        rawJson.contains('instant - adventure') ||
        rawJson.contains('sorcery - adventure')) {
      return true;
    }

    return false;
  }

  double get _effectiveMarketPrice {
    if (_currentItem.currentMarketPrice > 0) return _currentItem.currentMarketPrice;
    try {
      if (_dynamicData['prices'] is Map) {
        final prices = _dynamicData['prices'] as Map;
        final usd = prices['usd']?.toString();
        final usdFoil = prices['usd_foil']?.toString();
        final usdEtched = prices['usd_etched']?.toString();
        final eur = prices['eur']?.toString();
        final eurFoil = prices['eur_foil']?.toString();
        final p = double.tryParse(usd ?? '') ??
            double.tryParse(usdFoil ?? '') ??
            double.tryParse(usdEtched ?? '') ??
            double.tryParse(eur ?? '') ??
            double.tryParse(eurFoil ?? '') ??
            0.0;
        if (p > 0) return p;
      }
    } catch (_) {}
    return 0.0;
  }

  Map<String, dynamic>? get _activeFace {
    if (_isAdventureCard()) {
      final faces = _getCardFaces();
      return faces.isNotEmpty ? faces[0] : null;
    }
    final faces = _getCardFaces();
    if (faces.length > 1) {
      return _isFlipped ? faces[1] : faces[0];
    } else if (faces.length == 1) {
      return faces[0];
    }
    return null;
  }

  String? _getBackImageUrl() {
    if (_isAdventureCard()) return null;
    if (_dynamicData['back_image_url'] is String &&
        (_dynamicData['back_image_url'] as String).isNotEmpty) {
      return _dynamicData['back_image_url'] as String;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.length > 1) {
      final back = faces[1];
      if (back is Map) {
        if (back['image_uris'] is Map) {
          final uris = back['image_uris'] as Map<String, dynamic>;
          final url = uris['normal'] ??
              uris['large'] ??
              uris['small'] ??
              uris['png'] ??
              uris['border_crop'] ??
              uris['art_crop'];
          if (url != null && url.toString().isNotEmpty) return url.toString();
        }
        final direct = back['image_url']?.toString() ?? back['imageUrl']?.toString();
        if (direct != null && direct.isNotEmpty) return direct;
      }
    }
    final hasSlash =
        _currentItem.name.contains(' // ') || _currentItem.name.contains('//');
    if (hasSlash && _currentItem.imageUrl.isNotEmpty) {
      if (_currentItem.imageUrl.contains('/front/')) {
        return _currentItem.imageUrl.replaceAll('/front/', '/back/');
      }
      if (_currentItem.imageUrl.contains('/front.')) {
        return _currentItem.imageUrl.replaceAll('/front.', '/back.');
      }
      if (_currentItem.imageUrl.contains('_front.')) {
        return _currentItem.imageUrl.replaceAll('_front.', '_back.');
      }
    }
    return null;
  }

  String _getFrontImageUrl() {
    if (_currentItem.imageUrl.isNotEmpty) return _currentItem.imageUrl;
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      final front = faces[0];
      if (front is Map) {
        if (front['image_uris'] is Map) {
          final uris = front['image_uris'] as Map<String, dynamic>;
          final url = uris['normal'] ??
              uris['large'] ??
              uris['small'] ??
              uris['png'] ??
              uris['border_crop'] ??
              uris['art_crop'];
          if (url != null && url.toString().isNotEmpty) return url.toString();
        }
        final direct = front['image_url']?.toString() ?? front['imageUrl']?.toString();
        if (direct != null && direct.isNotEmpty) return direct;
      }
    }
    return '';
  }

  bool get _hasFlipArt => !_isAdventureCard() && _getBackImageUrl() != null;
  bool get _hasMultipleFaces =>
      !_isAdventureCard() && (_hasFlipArt || _getCardFaces().length > 1);

  void _toggleFlip() {
    if (!_hasMultipleFaces) return;
    final nextFlipped = !_isFlipped;
    if (_hasFlipArt) {
      if (nextFlipped) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
    setState(() {
      _isFlipped = nextFlipped;
    });
  }

  bool _isMtgCard() {
    final col = _currentItem.collectionType.toLowerCase();
    return col == 'mtg' || col.contains('magic');
  }

  Future<void> _healMissingMultiFaceData() async {
    if (!mounted || !_isMtgCard()) return;
    final hasCardFaces = _dynamicData['card_faces'] is List &&
        (_dynamicData['card_faces'] as List).isNotEmpty;
    final oracle = _dynamicData['oracle_text']?.toString() ?? '';
    final isDfcName =
        _currentItem.name.contains(' // ') || _currentItem.name.contains('//');
    final isMissingFaceData =
        isDfcName && (!hasCardFaces || oracle.trim().isEmpty);
    final isMissingPrice = _currentItem.currentMarketPrice <= 0.0;
    final isMissingImage = _currentItem.imageUrl.isEmpty;

    if (!isMissingFaceData && !isMissingPrice && !isMissingImage) return;

    try {
      final scryfallId = _dynamicData['scryfall_id']?.toString() ??
          _dynamicData['id']?.toString() ??
          _currentItem.id;
      final service = ref.read(scryfallServiceProvider);
      final cardJson = await service.fetchCardDetails(
        scryfallId: scryfallId,
        name: _currentItem.name,
      );

      if (cardJson != null && mounted) {
        final companion = mapScryfallCardToCompanion(cardJson);
        final newDynamic =
            jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;

        if (_dynamicData['cached_rulings'] != null) {
          newDynamic['cached_rulings'] = _dynamicData['cached_rulings'];
        }
        if (_dynamicData['deck_history'] != null) {
          newDynamic['deck_history'] = _dynamicData['deck_history'];
        }
        final newDynamicStr = jsonEncode(newDynamic);

        final newFlavor =
            companion.flavorName.present ? companion.flavorName.value : null;
        final newImage = companion.imageUrl.value;
        final newPrice = companion.currentMarketPrice.value;

        final dao = ref.read(vaultDaoProvider);
        await dao.updateItemMetadata(
          _currentItem.id,
          flavorName: newFlavor,
          imageUrl: newImage.isNotEmpty ? newImage : null,
          currentMarketPrice: newPrice > 0 ? newPrice : null,
          dynamicData: newDynamicStr,
        );

        if (mounted) {
          setState(() {
            _dynamicData = newDynamic;
            _currentItem = _currentItem.copyWith(
              flavorName: Value(newFlavor ?? _currentItem.flavorName),
              imageUrl:
                  newImage.isNotEmpty ? newImage : _currentItem.imageUrl,
              currentMarketPrice: newPrice > 0
                  ? newPrice
                  : _currentItem.currentMarketPrice,
              dynamicData: newDynamicStr,
            );
            if (_isFlipped && _hasFlipArt) {
              _flipController.value = 1.0;
            }
          });
        }
      }
    } catch (_) {
      // Graceful offline fallback
    }
  }

  Future<void> _fetchAndCacheRulings() async {
    if (!mounted || !_isMtgCard()) return;
    if (_cachedRulings.isNotEmpty || _dynamicData.containsKey('cached_rulings')) {
      return;
    }

    setState(() => _isLoadingRulings = true);

    try {
      final scryfallId = _dynamicData['scryfall_id']?.toString() ??
          _dynamicData['id']?.toString() ??
          _currentItem.id;

      final service = ref.read(scryfallServiceProvider);
      final rulings = await service.fetchCardRulings(scryfallId);

      if (!mounted) return;

      if (rulings != null) {
        if (rulings.isNotEmpty) {
          setState(() {
            _cachedRulings = rulings;
          });
        }
        await _persistCachedRulings(rulings);
      }
    } catch (_) {
      // Graceful error handling
    } finally {
      if (mounted) {
        setState(() => _isLoadingRulings = false);
      }
    }
  }

  Future<void> _persistCachedRulings(List<ScryfallRuling> rulings) async {
    try {
      final dao = ref.read(vaultDaoProvider);
      final existing = await dao.getItemById(_currentItem.id);
      if (existing == null) return;

      Map<String, dynamic> data = {};
      if (existing.dynamicData.isNotEmpty) {
        try {
          data = jsonDecode(existing.dynamicData) as Map<String, dynamic>;
        } catch (_) {}
      }
      data['cached_rulings'] = rulings.map((r) => r.toJson()).toList();
      final updatedJson = jsonEncode(data);

      await (dao.attachedDatabase.update(dao.attachedDatabase.vaultItems)
            ..where((t) => t.id.equals(_currentItem.id)))
          .write(VaultItemsCompanion(dynamicData: Value(updatedJson)));

      if (mounted) {
        setState(() {
          _dynamicData = data;
          _currentItem = _currentItem.copyWith(dynamicData: updatedJson);
        });
      }
    } catch (_) {
      // Gracefully ignore database persistence errors in test environments
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isSavingNotes = true);
    final dao = ref.read(vaultDaoProvider);
    final text = _notesController.text.trim();
    await dao.updateItemNotesAndDecks(
      _currentItem.id,
      personalNotes: text,
      deckTags: _deckHistory,
    );

    if (mounted) {
      setState(() {
        _isSavingNotes = false;
        _currentItem = _currentItem.copyWith(
          personalNotes: Value(text.isNotEmpty ? text : null),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card notes saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addDeckTag() async {
    final tag = _deckTagController.text.trim();
    if (tag.isEmpty || _deckHistory.contains(tag)) return;

    setState(() {
      _deckHistory.add(tag);
      _deckTagController.clear();
    });

    final dao = ref.read(vaultDaoProvider);
    await dao.updateItemNotesAndDecks(
      _currentItem.id,
      deckTags: _deckHistory,
    );
  }

  Future<void> _removeDeckTag(String tag) async {
    setState(() {
      _deckHistory.remove(tag);
    });

    final dao = ref.read(vaultDaoProvider);
    await dao.updateItemNotesAndDecks(
      _currentItem.id,
      deckTags: _deckHistory,
    );
  }

  Future<void> _addToVault() async {
    final dao = ref.read(vaultDaoProvider);
    await dao.upsertScannedCardToInbox(_currentItem);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${_currentItem.name}" to Inbox'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwned = _currentItem.quantity > 0;
    final activeFace = _activeFace;
    final manaCost = activeFace?['mana_cost']?.toString() ??
        _dynamicData['mana_cost']?.toString() ??
        _dynamicData['mana']?.toString() ??
        '';
    final typeLine = activeFace?['type_line']?.toString() ??
        _dynamicData['type_line']?.toString() ??
        _dynamicData['type']?.toString() ??
        _currentItem.collectionType.toUpperCase();
    String oracleText = activeFace?['oracle_text']?.toString() ?? '';
    if (oracleText.trim().isEmpty && _dynamicData['oracle_text'] != null) {
      final rawOracle = _dynamicData['oracle_text'].toString();
      if (rawOracle.contains(' // ') || rawOracle.contains('//')) {
        final sep = rawOracle.contains(' // ') ? ' // ' : '//';
        final parts = rawOracle.split(sep);
        oracleText = (_isFlipped && parts.length > 1) ? parts[1].trim() : parts[0].trim();
      } else {
        oracleText = rawOracle;
      }
    }
    if (oracleText.trim().isEmpty && _getCardFaces().isNotEmpty) {
      final faces = _getCardFaces();
      if (_isFlipped && faces.length > 1) {
        oracleText = (faces[1]['oracle_text'] as String?)?.trim() ?? '';
      } else if (faces.isNotEmpty) {
        oracleText = (faces[0]['oracle_text'] as String?)?.trim() ?? '';
      }
      if (oracleText.trim().isEmpty) {
        oracleText = faces
            .map((f) => (f['oracle_text'] as String?)?.trim() ?? '')
            .where((t) => t.isNotEmpty)
            .join('\n\n//\n\n');
      }
    }
    final rarity = _dynamicData['rarity']?.toString() ?? '';
    final power =
        activeFace?['power']?.toString() ?? _dynamicData['power']?.toString();
    final toughness = activeFace?['toughness']?.toString() ??
        _dynamicData['toughness']?.toString();
    final loyalty = activeFace?['loyalty']?.toString() ??
        _dynamicData['loyalty']?.toString();
    final rulings = _dynamicData['rulings']?.toString() ??
        _dynamicData['use_cases']?.toString() ??
        '';
    String flavorText = activeFace?['flavor_text']?.toString() ?? '';
    if (flavorText.trim().isEmpty && _dynamicData['flavor_text'] != null) {
      final rawFlavor = _dynamicData['flavor_text'].toString();
      if (rawFlavor.contains(' // ') || rawFlavor.contains('//')) {
        final sep = rawFlavor.contains(' // ') ? ' // ' : '//';
        final parts = rawFlavor.split(sep);
        flavorText = (_isFlipped && parts.length > 1) ? parts[1].trim() : parts[0].trim();
      } else {
        flavorText = rawFlavor;
      }
    }
    final rawKeywords = _dynamicData['keywords'];
    final keywordsList = rawKeywords is List ? rawKeywords : null;
    final mechanics = _isMtgCard()
        ? MtgKeywordGlossary.extractKeywords(
            keywords: keywordsList,
            oracleText: oracleText,
          )
        : const <String>[];

    // Profit / Loss calculations
    final effectivePrice = _effectiveMarketPrice;
    final delta = (effectivePrice - _currentItem.acquiredPrice) * _currentItem.quantity;
    final pct = _currentItem.acquiredPrice > 0
        ? ((effectivePrice - _currentItem.acquiredPrice) / _currentItem.acquiredPrice) * 100
        : 0.0;
    final isProfit = delta >= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.96,
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

              // Sheet Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentItem.flavorName != null &&
                                    _currentItem.flavorName!.isNotEmpty
                                ? _currentItem.flavorName!
                                : (activeFace?['name']?.toString() ??
                                    _currentItem.name),
                            style: AppTypography.heading1.copyWith(fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (_currentItem.flavorName != null &&
                                  _currentItem.flavorName!.isNotEmpty) ...[
                                Text(
                                  '[${_currentItem.name}]',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.accentCyan,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(' • ',
                                    style: TextStyle(color: AppColors.textMuted)),
                              ] else if (_hasMultipleFaces && activeFace != null) ...[
                                Text(
                                  'Face ${_isFlipped ? 2 : 1}/${_getCardFaces().length}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.accentCyan,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(' • ',
                                    style: TextStyle(color: AppColors.textMuted)),
                              ],
                              Flexible(
                                child: Text(
                                  _currentItem.setOrSeries,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (rarity.isNotEmpty) ...[
                                const Text(' • ',
                                    style: TextStyle(color: AppColors.textMuted)),
                                Text(
                                  rarity.toUpperCase(),
                                  style: AppTypography.caption.copyWith(
                                    color: _getRarityColor(rarity),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

              // Scrollable Details Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  children: [
                    // Card Artwork & Core Metadata Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Image with aspect ratio and elevation
                        _buildCardArtwork(),

                        const SizedBox(width: 16),

                        // High-level overview
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type Line
                              Text(
                                typeLine,
                                style: AppTypography.heading2.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 6),

                              // Mana Cost (if available)
                              if (manaCost.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Text(
                                    manaCost,
                                    style: const TextStyle(
                                      color: AppColors.accentCyan,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Market Price Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAmber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  _effectiveMarketPrice > 0
                                      ? 'Market: \$${_effectiveMarketPrice.toStringAsFixed(2)}'
                                      : 'Market: Check',
                                  style: const TextStyle(
                                    color: AppColors.accentAmber,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Power / Toughness / Loyalty
                              if (power != null && toughness != null && power.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'P/T: $power / $toughness',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (loyalty != null && loyalty.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Loyalty: $loyalty',
                                    style: const TextStyle(
                                      color: AppColors.accentViolet,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Unowned Catalog Card Action Bar
                    if (!isOwned) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('card_detail_add_to_vault'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: AppColors.textDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                          label: const Text(
                            'Add to Vault / Inbox',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                          onPressed: _addToVault,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section 1: Oracle & Rules Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(Icons.auto_stories_rounded, 'Oracle Rules Text'),
                        if (_hasMultipleFaces && _getCardFaces().length > 1)
                          InkWell(
                            key: const Key('card_detail_switch_face_button'),
                            onTap: _toggleFlip,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.accentCyan),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isFlipped ? 'View Face 1' : 'View Face 2',
                                    style: const TextStyle(
                                      color: AppColors.accentCyan,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 18),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: _isAdventureCard()
                          ? _buildAdventureOracleContent(oracleText, flavorText)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_hasMultipleFaces && activeFace != null && _getCardFaces().length > 1) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.surfaceBorderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isFlipped ? Icons.flip_to_back : Icons.flip_to_front,
                                          size: 13,
                                          color: AppColors.accentCyan,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${activeFace['name'] ?? (_isFlipped ? 'Back Face' : 'Front Face')} — ${activeFace['type_line'] ?? ''}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Text(
                                  oracleText.isNotEmpty ? oracleText : 'No rules text available for this card.',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5,
                                    height: 1.45,
                                  ),
                                ),
                                if (flavorText.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    flavorText,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),

                    // Card Mechanics & Rulings
                    _buildCardMechanicsAndRulings(mechanics, _cachedRulings, _isLoadingRulings),

                    // Section 2: Format Legalities
                    _buildFormatLegalities(),

                    // Section 3: Official Rulings & Textbox Clarifications
                    if (_cachedRulings.isEmpty && rulings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader(Icons.gavel_rounded, 'Rules Text Clarifications'),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 18),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          rulings,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    // Section 4: Collection Portfolio Metrics (Owned Cards)
                    if (isOwned) ...[
                      const SizedBox(height: 8),
                      _buildSectionHeader(Icons.analytics_outlined, 'Collection & Portfolio Metrics'),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 18),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildMetricBox('Owned Copies', '${_currentItem.quantity}x', AppColors.textPrimary),
                                const SizedBox(width: 10),
                                _buildMetricBox('Condition', _currentItem.condition, AppColors.accentCyan),
                                const SizedBox(width: 10),
                                _buildMetricBox('Graded', _currentItem.isGraded ? 'Yes' : 'Raw', AppColors.accentEmerald),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildMetricBox('Acquired Price', '\$${_currentItem.acquiredPrice.toStringAsFixed(2)}', AppColors.textSecondary),
                                const SizedBox(width: 10),
                                _buildMetricBox(
                                  'Profit / Loss',
                                  '${isProfit ? '+' : ''}\$${delta.toStringAsFixed(2)} (${isProfit ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                                  isProfit ? AppColors.accentEmerald : AppColors.accentRose,
                                ),
                              ],
                            ),
                            if (_currentItem.primaryBinderId != null && _currentItem.primaryBinderId!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.folder_special_rounded, size: 16, color: AppColors.accentViolet),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Binder: ${_currentItem.primaryBinderId}',
                                    style: const TextStyle(color: AppColors.accentVioletLight, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Section 5: Deck History & Associations
                    _buildSectionHeader(Icons.view_carousel_rounded, 'Deck History & Tags'),
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 18),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_deckHistory.isEmpty)
                            const Text(
                              'No deck history recorded yet.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _deckHistory.map((deck) {
                                return Chip(
                                  label: Text(deck, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                  backgroundColor: AppColors.surfaceHighlight,
                                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                                  onDeleted: () => _removeDeckTag(deck),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _deckTagController,
                                  decoration: InputDecoration(
                                    hintText: 'Add deck tag (e.g. Commander - Urza)...',
                                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                                    ),
                                  ),
                                  onSubmitted: (_) => _addDeckTag(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Add tag',
                                icon: const Icon(Icons.add_circle, color: AppColors.accentCyan),
                                onPressed: _addDeckTag,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 6: User-Submitted Use Cases & Notes
                    _buildSectionHeader(Icons.edit_note_rounded, 'Personal Notes & Strategy Tips'),
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 18),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Enter combos, strategy tips, or personal notes...',
                              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: _isSavingNotes
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                                      )
                                    : const Icon(Icons.save_rounded, size: 16),
                                label: const Text('Save Notes'),
                                onPressed: _isSavingNotes ? null : _saveNotes,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Pinned Bottom Quick Action Bar
              const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
              _buildQuickActionBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardArtwork() {
    final hasFlip = _hasFlipArt;

    final artwork = GestureDetector(
      onTap: hasFlip ? _toggleFlip : null,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;
          final isUnder = angle > (math.pi / 2);
          final backUrl = _getBackImageUrl();
          final frontUrl = _getFrontImageUrl();
          final currentUrl = isUnder ? (backUrl ?? frontUrl) : frontUrl;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardFaceContainer(currentUrl),
                  )
                : _buildCardFaceContainer(currentUrl),
          );
        },
      ),
    );

    return Hero(
      key: Key('card_artwork_${_currentItem.id}'),
      tag: 'card_artwork_${_currentItem.id}',
      child: Stack(
        children: [
          artwork,
          if (hasFlip)
            Positioned(
              bottom: 4,
              right: 4,
              child: Semantics(
                button: true,
                label: 'Flip card',
                hint: 'Toggles between front and back face',
                child: Tooltip(
                  message: 'Flip card',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('card_detail_flip_button'),
                      onTap: _toggleFlip,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.flip_camera_android_rounded,
                              size: 16,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardFaceContainer(String imageUrl) {
    return Container(
      width: 110,
      height: 154,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPlaceholderArt(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                );
              },
            )
          : _buildPlaceholderArt(),
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(
            _currentItem.name,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accentCyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.heading2.copyWith(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatLegalities() {
    final formats = ['Standard', 'Pioneer', 'Modern', 'Legacy', 'Vintage', 'Commander', 'Pauper'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.verified_outlined, 'Format Legalities'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: formats.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$f: Legal',
                style: const TextStyle(
                  color: AppColors.accentEmerald,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'mythic':
        return AppColors.accentAmber;
      case 'rare':
        return AppColors.accentAmberLight;
      case 'uncommon':
        return AppColors.accentCyan;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildAdventureOracleContent(String oracleText, String flavorText) {
    final faces = _getCardFaces();
    Map<String, dynamic> face0 = {};
    Map<String, dynamic> face1 = {};

    if (faces.length >= 2) {
      face0 = faces[0];
      face1 = faces[1];
    } else {
      final names = _currentItem.name.contains(' // ')
          ? _currentItem.name.split(' // ')
          : _currentItem.name.split('//');
      final oracles = oracleText.contains(' // ')
          ? oracleText.split(' // ')
          : oracleText.split('//');
      face0 = {
        'name': names[0].trim(),
        'type_line': _dynamicData['type_line']?.toString() ?? 'Creature',
        'mana_cost': _dynamicData['mana_cost']?.toString() ?? '',
        'oracle_text': oracles[0].trim(),
        'power': _dynamicData['power'],
        'toughness': _dynamicData['toughness'],
      };
      face1 = {
        'name': names.length > 1 ? names[1].trim() : 'Adventure Spell',
        'type_line': 'Instant — Adventure',
        'mana_cost': '',
        'oracle_text': oracles.length > 1 ? oracles[1].trim() : '',
      };
    }

    final name0 = face0['name']?.toString() ?? _currentItem.name;
    final mana0 = face0['mana_cost']?.toString() ?? '';
    final type0 = face0['type_line']?.toString() ?? '';
    final text0 = face0['oracle_text']?.toString() ?? '';
    final p0 = face0['power']?.toString();
    final t0 = face0['toughness']?.toString();
    final pt0 = (p0 != null && t0 != null && p0.isNotEmpty && t0.isNotEmpty)
        ? '$p0/$t0'
        : null;

    final name1 = face1['name']?.toString() ?? 'Adventure Spell';
    final mana1 = face1['mana_cost']?.toString() ?? '';
    final type1 = face1['type_line']?.toString() ?? 'Instant — Adventure';
    final text1 = face1['oracle_text']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Face 0: Main Permanent Spell
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                name0,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (mana0.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Text(
                  mana0,
                  style: const TextStyle(
                    color: AppColors.accentAmber,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (type0.isNotEmpty || pt0 != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (type0.isNotEmpty)
                Expanded(
                  child: Text(
                    type0,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (pt0 != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pt0,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (text0.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            text0,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],

        // Divider banner between Main Spell and Adventure Spell
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.accentCyan.withValues(alpha: 0.3),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories, size: 13, color: AppColors.accentCyan),
                    SizedBox(width: 6),
                    Text(
                      'ADVENTURE SPELL',
                      style: TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.accentCyan.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),

        // Face 1: Adventure Spell
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                name1,
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (mana1.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Text(
                  mana1,
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (type1.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            type1,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (text1.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            text1,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],

        // Flavor Text
        if (flavorText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            flavorText,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardMechanicsAndRulings(
    List<String> keywords,
    List<ScryfallRuling> rulings,
    bool isLoadingRulings,
  ) {
    if (!_isMtgCard() || (keywords.isEmpty && rulings.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.auto_awesome_rounded, 'Card Mechanics & Rulings'),
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Keywords list
              if (keywords.isNotEmpty) ...[
                for (int i = 0; i < keywords.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      keywords[i],
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    MtgKeywordGlossary.dictionary[keywords[i]] ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],

              // Divider between keywords and rulings
              if (keywords.isNotEmpty && rulings.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.surfaceBorderSubtle),
                ),
              ],

              // Scryfall rulings list
              if (rulings.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, size: 14, color: AppColors.accentAmber),
                    const SizedBox(width: 6),
                    Text(
                      'Official Rulings (${rulings.length})',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < rulings.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: AppColors.surfaceBorderSubtle),
                    ),
                  if (rulings[i].publishedAt.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          rulings[i].publishedAt,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    rulings[i].comment,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Action Bar & Actions
  // ---------------------------------------------------------------------------

  Widget _buildQuickActionBar(BuildContext context) {
    return Container(
      key: const Key('card_detail_quick_action_bar'),
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4
            : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: const Border(top: BorderSide(color: AppColors.surfaceBorderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Delete
          _buildQuickActionButton(
            key: const Key('quick_action_delete'),
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.accentRose,
            onTap: _confirmDeleteItem,
          ),

          // 2. Full Screen
          _buildQuickActionButton(
            key: const Key('quick_action_fullscreen'),
            icon: Icons.fullscreen_rounded,
            label: 'Full Screen',
            color: AppColors.accentCyan,
            onTap: _openFullScreenViewer,
          ),

          // 3. Add to Deck
          _buildQuickActionButton(
            key: const Key('quick_action_add_to_deck'),
            icon: Icons.playlist_add_rounded,
            label: 'Add to Deck',
            color: AppColors.accentVioletLight,
            onTap: _showAddToDeckDialog,
          ),

          // 4. Share
          _buildQuickActionButton(
            key: const Key('quick_action_share'),
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppColors.accentEmerald,
            onTap: _handleShareAction,
          ),

          // 5. Edit
          _buildQuickActionButton(
            key: const Key('quick_action_edit'),
            icon: Icons.edit_note_rounded,
            label: 'Edit',
            color: AppColors.accentAmber,
            onTap: _openEditModal,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('card_detail_delete_dialog'),
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Card?', style: AppTypography.heading2),
        content: Text(
          'Are you sure you want to remove "${_currentItem.name}" from your Vault? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            key: const Key('delete_cancel_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            key: const Key('delete_confirm_button'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final dao = ref.read(vaultDaoProvider);
      await dao.deleteItem(_currentItem.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${_currentItem.name}" from Vault'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openFullScreenViewer() {
    FullScreenCardViewer.show(context, _currentItem);
  }

  Future<void> _showAddToDeckDialog() async {
    final availableDecks = [
      'Edgar Markov Aristocrats',
      'Charizard ex / Pidgeot ex',
      'Yuriko, the Tiger\'s Shadow',
      'Ruby / Amethyst Bounce Control',
      'Lost Zone Giratina VSTAR',
      'Modern Mono-Green Tron',
    ];
    final customDeckController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add Card to Deck', style: AppTypography.heading2),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...availableDecks.map((deck) {
                    final inDeck = _deckHistory.contains(deck);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.style_rounded, color: AppColors.accentVioletLight, size: 20),
                      title: Text(deck, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
                      trailing: inDeck
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 20)
                          : const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan, size: 20),
                      onTap: () async {
                        if (!inDeck) {
                          setState(() {
                            _deckHistory.add(deck);
                            _dynamicData['deck_history'] = _deckHistory;
                          });
                          await ref.read(vaultDaoProvider).updateItemNotesAndDecks(
                                _currentItem.id,
                                deckTags: _deckHistory,
                              );
                        }
                        if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to "$deck"'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customDeckController,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Or enter new deck name...',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            filled: true,
                            fillColor: AppColors.surfaceRaised,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.surfaceBorder),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Create and add',
                        icon: const Icon(Icons.add_circle, color: AppColors.accentCyan, size: 28),
                        onPressed: () async {
                          final name = customDeckController.text.trim();
                          if (name.isNotEmpty && !_deckHistory.contains(name)) {
                            setState(() {
                              _deckHistory.add(name);
                              _dynamicData['deck_history'] = _deckHistory;
                            });
                            await ref.read(vaultDaoProvider).updateItemNotesAndDecks(
                                  _currentItem.id,
                                  deckTags: _deckHistory,
                                );
                            if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added to "$name"'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleShareAction() {
    final isLoggedIn = ref.read(isUserLoggedInProvider);
    if (!isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('share_login_dialog'),
          backgroundColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sign in to Share', style: AppTypography.heading2),
          content: const Text(
            'You must be signed in to share cards with the Countr community.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              key: const Key('share_login_cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              key: const Key('share_login_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.textDark,
              ),
              onPressed: () {
                ref.read(isUserLoggedInProvider.notifier).state = true;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signed in successfully!'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      _showShareDialog();
    }
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('card_share_dialog'),
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.share_rounded, color: AppColors.accentEmerald, size: 22),
            const SizedBox(width: 8),
            Text('Share ${_currentItem.name}', style: AppTypography.heading2.copyWith(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_currentItem.name} • ${_currentItem.setOrSeries}',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _effectiveMarketPrice > 0
                  ? 'Market Value: \$${_effectiveMarketPrice.toStringAsFixed(2)}'
                  : 'Market Value: Unavailable',
              style: const TextStyle(color: AppColors.accentCyan, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this card with friends or export card data to external collection formats.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('share_dialog_close'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            key: const Key('share_copy_link_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentEmerald,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Card Info'),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied "${_currentItem.name}" link to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openEditModal() async {
    final updated = await EditCardModal.show(context, _currentItem);
    if (mounted) {
      final latest = await ref.read(vaultDaoProvider).getItemById(_currentItem.id);
      final finalItem = latest ?? updated;
      if (finalItem != null && mounted) {
        setState(() {
          _currentItem = finalItem;
          _notesController.text = finalItem.personalNotes ?? '';
          _parseDynamicData();
        });
      }
    }
  }
}

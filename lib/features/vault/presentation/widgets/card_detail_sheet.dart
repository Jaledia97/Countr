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
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/edit_card_modal.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/multi_deck_allocation_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';
import 'package:countr/features/decks/presentation/widgets/conflict_resolution_modal.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/values/presentation/widgets/cost_basis_pnl_widget.dart';
import 'package:countr/features/values/presentation/widgets/liquidity_reality_check_widget.dart';
import 'package:countr/features/values/presentation/widgets/fifty_two_week_range_bar.dart';
import 'package:countr/features/values/presentation/widgets/condition_treatment_matrix_widget.dart';
import 'package:countr/features/values/presentation/widgets/market_spread_table_widget.dart';
import 'package:countr/features/values/presentation/widgets/freshness_badge_widget.dart';
import 'package:countr/features/values/presentation/widgets/interactive_multi_line_chart.dart';
import 'package:countr/features/decks/presentation/widgets/deck_gear_section.dart';

/// Available tabs in the card detail sheet.
enum CardDetailTab { details, valuesTab }

/// Draggable modal bottom sheet displaying full card breakdown, oracle rules text,
/// community use cases, deck history, and collection portfolio analytics.
///
/// Supports horizontal swiping across active filtered Vault items via [PageView.builder],
/// while preserving single-item backward compatibility for existing tests.
class CardDetailSheet extends ConsumerStatefulWidget {
  final VaultItem? item;
  final List<VaultItem>? items;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final bool fetchOnlinePrintings;
  final String? deckId;
  final Deck? deck;

  const CardDetailSheet({
    super.key,
    this.item,
    this.items,
    this.initialIndex = 0,
    this.onPageChanged,
    this.fetchOnlinePrintings = false,
    this.deckId,
    this.deck,
  }) : assert(item != null || (items != null && items.length > 0),
            'Either item or a non-empty items list must be provided.');

  /// Opens the CardDetailSheet inside a draggable scrollable modal bottom sheet.
  static Future<void> show(
    BuildContext context,
    VaultItem item, {
    List<VaultItem>? items,
    int? initialIndex,
    ValueChanged<int>? onPageChanged,
    bool fetchOnlinePrintings = false,
    String? deckId,
    Deck? deck,
  }) {
    final effectiveItems = items ?? [item];
    final effectiveIndex = initialIndex ?? (items != null ? items.indexOf(item) : 0);
    final resolvedIndex = effectiveIndex >= 0 ? effectiveIndex : 0;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => CardDetailSheet(
        item: item,
        items: effectiveItems,
        initialIndex: resolvedIndex,
        onPageChanged: onPageChanged,
        fetchOnlinePrintings: fetchOnlinePrintings,
        deckId: deckId,
        deck: deck,
      ),
    );
  }

  @override
  ConsumerState<CardDetailSheet> createState() => _CardDetailSheetState();
}


class _CardDetailSheetState extends ConsumerState<CardDetailSheet>
    with SingleTickerProviderStateMixin {
  late List<VaultItem> _items;
  late int _currentIndex;
  late PageController _pageController;
  ScrollController? _activeSheetScrollController;

  CardDetailTab _selectedTab = CardDetailTab.details;
  late TextEditingController _notesController;
  late TextEditingController _deckTagController;
  late TextEditingController _binderPageController;
  late TextEditingController _binderSlotController;
  late TextEditingController _purchasePriceController;
  late VaultItem _currentItem;
  Map<String, dynamic> _dynamicData = {};
  List<String> _deckHistory = [];
  bool _isSavingNotes = false;
  CardPrintCandidate? _previewCandidate;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isFlipped = false;

  List<ScryfallRuling> _cachedRulings = [];
  bool _isLoadingRulings = false;

  @override
  void initState() {
    super.initState();
    if (widget.items != null && widget.items!.isNotEmpty) {
      _items = List<VaultItem>.from(widget.items!);
      _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    } else if (widget.item != null) {
      _items = [widget.item!];
      _currentIndex = 0;
    } else {
      _items = [];
      _currentIndex = 0;
    }

    _currentItem = _items.isNotEmpty ? _items[_currentIndex] : widget.item!;
    _pageController = PageController(initialPage: _currentIndex);
    _notesController = TextEditingController(text: _currentItem.notes ?? _currentItem.personalNotes ?? '');
    _binderPageController = TextEditingController(text: _currentItem.binderPage?.toString() ?? '');
    _binderSlotController = TextEditingController(text: _currentItem.binderSlot ?? '');
    _purchasePriceController = TextEditingController(
      text: (_currentItem.purchasePrice ?? _currentItem.acquiredPrice) > 0
          ? (_currentItem.purchasePrice ?? _currentItem.acquiredPrice).toStringAsFixed(2)
          : '',
    );
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
    _pageController.dispose();
    _notesController.dispose();
    _binderPageController.dispose();
    _binderSlotController.dispose();
    _purchasePriceController.dispose();
    _deckTagController.dispose();
    _flipController.dispose();
    _activeSheetScrollController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(CardDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != null && widget.items != oldWidget.items) {
      _items = List<VaultItem>.from(widget.items!);
      if (_currentIndex >= _items.length) {
        _currentIndex = math.max(0, _items.length - 1);
      }
      _syncCurrentItem();
    } else if (widget.item != null &&
        (oldWidget.item?.id != widget.item?.id ||
            oldWidget.item?.dynamicData != widget.item?.dynamicData ||
            (_cachedRulings.isEmpty && !_dynamicData.containsKey('cached_rulings')))) {
      _items = [widget.item!];
      _currentIndex = 0;
      _syncCurrentItem();
    }
  }

  void _syncCurrentItem() {
    if (_items.isNotEmpty && _currentIndex < _items.length) {
      _currentItem = _items[_currentIndex];
    } else if (widget.item != null) {
      _currentItem = widget.item!;
    }
    _notesController.text = _currentItem.notes ?? _currentItem.personalNotes ?? '';
    _binderPageController.text = _currentItem.binderPage?.toString() ?? '';
    _binderSlotController.text = _currentItem.binderSlot ?? '';
    _purchasePriceController.text = (_currentItem.purchasePrice ?? _currentItem.acquiredPrice) > 0
        ? (_currentItem.purchasePrice ?? _currentItem.acquiredPrice).toStringAsFixed(2)
        : '';
    _deckTagController.clear();
    _previewCandidate = null;
    _isFlipped = false;
    _flipController.reset();
    _parseDynamicData();
    _fetchAndCacheRulings();
    _healMissingMultiFaceData();
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex || index < 0 || index >= _items.length) return;

    setState(() {
      _currentIndex = index;
      _currentItem = _items[_currentIndex];
      _notesController.text = _currentItem.notes ?? _currentItem.personalNotes ?? '';
      _binderPageController.text = _currentItem.binderPage?.toString() ?? '';
      _binderSlotController.text = _currentItem.binderSlot ?? '';
      _purchasePriceController.text = (_currentItem.purchasePrice ?? _currentItem.acquiredPrice) > 0
          ? (_currentItem.purchasePrice ?? _currentItem.acquiredPrice).toStringAsFixed(2)
          : '';
      _deckTagController.clear();
      _previewCandidate = null;
      _isFlipped = false;
      _flipController.reset();
      _parseDynamicData();
    });

    widget.onPageChanged?.call(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_activeSheetScrollController != null &&
            _activeSheetScrollController!.hasClients &&
            _activeSheetScrollController!.offset > 0) {
          _activeSheetScrollController!.jumpTo(0.0);
        }
        _fetchAndCacheRulings();
        _healMissingMultiFaceData();
      }
    });
  }

  void _parseDynamicData() {
    if (_currentItem.dynamicData.isNotEmpty) {
      try {
        _dynamicData = jsonDecode(_currentItem.dynamicData) as Map<String, dynamic>;
        final rawDecks = _dynamicData['deck_history'];
        if (rawDecks is List) {
          _deckHistory = rawDecks.map((e) => e.toString()).toList();
        } else {
          _deckHistory = [];
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
        } else {
          _cachedRulings = [];
        }
      } catch (e, stackTrace) {
        debugPrint('[CardDetailSheet.initState] Failed parsing dynamicData: $e\n$stackTrace');
        _dynamicData = {};
        _deckHistory = [];
        _cachedRulings = [];
      }
    } else {
      _dynamicData = {};
      _deckHistory = [];
      _cachedRulings = [];
    }
  }

  Map<String, dynamic> _parseItemData(VaultItem item) {
    if (item.id == _currentItem.id && _dynamicData.isNotEmpty) {
      return _dynamicData;
    }
    if (item.dynamicData.isNotEmpty) {
      try {
        return jsonDecode(item.dynamicData) as Map<String, dynamic>;
      } catch (e, stackTrace) {
        debugPrint('[CardDetailSheet._parseItemData] Failed decoding dynamicData for ${item.id}: $e\n$stackTrace');
      }
    }
    return const {};
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

  List<Map<String, dynamic>> _getCardFacesForItem(VaultItem item, Map<String, dynamic> data) {
    if (item.id == _currentItem.id) {
      return _getCardFaces();
    }
    final faces = data['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      return faces.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    final hasSlash = item.name.contains(' // ') || item.name.contains('//');
    if (hasSlash) {
      final sep = item.name.contains(' // ') ? ' // ' : '//';
      final names = item.name.split(sep);
      final oracle = data['oracle_text']?.toString() ?? '';
      final oracleSep = oracle.contains(' // ')
          ? ' // '
          : (oracle.contains('//') ? '//' : null);
      final oracles = oracleSep != null ? oracle.split(oracleSep) : [oracle, ''];
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

  bool _isAdventureCardForItem(VaultItem item, Map<String, dynamic> data) {
    if (item.id == _currentItem.id) {
      return _isAdventureCard();
    }
    final layout = data['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'adventure') return true;

    final typeLine = data['type_line']?.toString().toLowerCase() ?? '';
    if (typeLine.contains('adventure')) return true;

    final faces = _getCardFacesForItem(item, data);
    for (final face in faces) {
      final faceType = face['type_line']?.toString().toLowerCase() ?? '';
      if (faceType.contains('adventure')) return true;
    }

    final rawJson = item.dynamicData.toLowerCase();
    return rawJson.contains('"layout":"adventure"') ||
        rawJson.contains('"layout": "adventure"') ||
        rawJson.contains('instant — adventure') ||
        rawJson.contains('sorcery — adventure') ||
        rawJson.contains('instant - adventure') ||
        rawJson.contains('sorcery - adventure');
  }

  bool _isDfc() {
    if (_isAdventureCard()) return false;
    final layout = _dynamicData['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'transform' ||
        layout == 'modal_dfc' ||
        layout == 'reversible_card' ||
        layout == 'double_faced_token' ||
        layout == 'art_series') {
      return true;
    }
    if (layout == 'adventure' ||
        layout == 'split' ||
        layout == 'flip' ||
        layout == 'normal' ||
        layout == 'leveler' ||
        layout == 'saga' ||
        layout == 'class') {
      return false;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.length > 1) {
      final backFace = faces[1];
      if (backFace is Map) {
        final uris = backFace['image_uris'];
        final img = backFace['image_url'] ?? backFace['imageUrl'];
        if ((uris is Map && uris.isNotEmpty) ||
            (img != null && img.toString().isNotEmpty)) {
          return true;
        }
      }
    }
    if (_dynamicData['back_image_url'] is String &&
        (_dynamicData['back_image_url'] as String).isNotEmpty) {
      return true;
    }
    return false;
  }

  double get _effectiveMarketPrice {
    if (_currentItem.currentMarketPrice > 0) return _currentItem.currentMarketPrice;
    return VaultPricingHelper.extractFromDynamicData(_dynamicData);
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
    final layout = _dynamicData['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'adventure' || layout == 'split' || layout == 'flip') return null;

    if (_dynamicData['back_image_url'] is String &&
        (_dynamicData['back_image_url'] as String).isNotEmpty) {
      return _dynamicData['back_image_url'] as String;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.length > 1) {
      final backFace = faces[1];
      if (backFace is Map) {
        final uris = backFace['image_uris'];
        if (uris is Map && uris['normal'] is String) {
          return uris['normal'] as String;
        }
        if (uris is Map && uris['large'] is String) {
          return uris['large'] as String;
        }
        if (uris is Map && uris['small'] is String) {
          return uris['small'] as String;
        }
        final img = backFace['image_url'] ?? backFace['imageUrl'];
        if (img is String && img.isNotEmpty) {
          return img;
        }
      }
    }
    return null;
  }

  String _getFrontImageUrl() {
    if (_previewCandidate != null && _previewCandidate!.imageUrl.isNotEmpty) {
      return _previewCandidate!.imageUrl;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      final frontFace = faces[0];
      if (frontFace is Map) {
        final uris = frontFace['image_uris'];
        if (uris is Map && uris['normal'] is String) {
          return uris['normal'] as String;
        }
        if (uris is Map && uris['large'] is String) {
          return uris['large'] as String;
        }
        if (uris is Map && uris['small'] is String) {
          return uris['small'] as String;
        }
        final img = frontFace['image_url'] ?? frontFace['imageUrl'];
        if (img is String && img.isNotEmpty) {
          return img;
        }
      }
    }
    return _currentItem.imageUrl;
  }

  bool get _hasFlipArt => _isDfc() && _getBackImageUrl() != null;
  bool get _hasMultipleFaces => _getCardFaces().length > 1;

  void _toggleFlip() {
    if (!_hasFlipArt && !_hasMultipleFaces) return;

    if (_flipController.isAnimating) return;

    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }

    setState(() {
      _isFlipped = !_isFlipped;
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
            if (_currentIndex < _items.length) {
              _items[_currentIndex] = _currentItem;
            }
            if (_isFlipped && _hasFlipArt) {
              _flipController.value = 1.0;
            }
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[CardDetailSheet._fetchOnlinePrintings] Failed: $e\n$stackTrace');
      // Graceful offline fallback
    }
  }

  Future<void> _fetchAndCacheRulings() async {
    if (!mounted || !_isMtgCard()) return;
    if (_isLoadingRulings || _cachedRulings.isNotEmpty || _dynamicData.containsKey('cached_rulings')) {
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
        _dynamicData['cached_rulings'] = rulings.map((r) => r.toJson()).toList();
        if (rulings.isNotEmpty) {
          setState(() {
            _cachedRulings = rulings;
          });
        }
        await _persistCachedRulings(rulings);
      }
    } catch (e, stackTrace) {
      debugPrint('[CardDetailSheet._fetchAndCacheRulings] Failed: $e\n$stackTrace');
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
        } catch (e, stackTrace) {
          debugPrint('[CardDetailSheet._persistCachedRulings] Failed decoding existing dynamicData: $e\n$stackTrace');
        }
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
          if (_currentIndex < _items.length) {
            _items[_currentIndex] = _currentItem;
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[CardDetailSheet._persistCachedRulings] Database update failed: $e\n$stackTrace');
      // Gracefully ignore database persistence errors in test environments
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isSavingNotes = true);
    final dao = ref.read(vaultDaoProvider);
    final text = _notesController.text.trim();
    await dao.updateItemCardDetails(
      id: _currentItem.id,
      notes: text,
      personalNotes: text,
    );

    if (mounted) {
      setState(() {
        _isSavingNotes = false;
        _currentItem = _currentItem.copyWith(
          notes: Value(text.isNotEmpty ? text : null),
          personalNotes: Value(text.isNotEmpty ? text : null),
        );
        if (_currentIndex < _items.length) {
          _items[_currentIndex] = _currentItem;
        }
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

  bool get _isPrivacyMode {
    try {
      return ref.watch(privacyModeProvider);
    } catch (_) {
      return false;
    }
  }

  AppCurrency get _baseCurrency {
    try {
      return ref.watch(baseCurrencyProvider);
    } catch (_) {
      return AppCurrency.usd;
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveItemAsync = ref.watch(vaultItemProvider(_currentItem.id));
    final liveItem = liveItemAsync.asData?.value;
    if (liveItem != null && (liveItem != _currentItem || liveItem.dynamicData != _currentItem.dynamicData)) {
      _currentItem = liveItem;
      if (_currentIndex < _items.length) {
        _items[_currentIndex] = liveItem;
      }
      _parseDynamicData();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        _activeSheetScrollController = scrollController;
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

              // Swiping Card View Area
              Expanded(
                child: PageView.builder(
                  key: const Key('card_detail_page_view'),
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (pageCtx, index) {
                    final item = _items[index];
                    final isCurrent = index == _currentIndex;
                    final activeScrollController = isCurrent ? scrollController : null;
                    return _buildCardPage(pageCtx, item, index, isCurrent, activeScrollController);
                  },
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

  Widget _buildCardPage(
    BuildContext context,
    VaultItem item,
    int index,
    bool isCurrent,
    ScrollController? activeScrollController,
  ) {
    final itemData = _parseItemData(item);
    final cardFaces = _getCardFacesForItem(item, itemData);
    final isAdventure = _isAdventureCardForItem(item, itemData);
    final hasMultiple = cardFaces.length > 1;

    final Map<String, dynamic>? activeFace = isCurrent
        ? _activeFace
        : (cardFaces.isNotEmpty ? cardFaces[0] : null);

    final manaCost = activeFace?['mana_cost']?.toString() ??
        itemData['mana_cost']?.toString() ??
        itemData['mana']?.toString() ??
        '';

    final typeLine = activeFace?['type_line']?.toString() ??
        itemData['type_line']?.toString() ??
        itemData['type']?.toString() ??
        item.collectionType.toUpperCase();

    String oracleText = activeFace?['oracle_text']?.toString() ?? '';
    if (oracleText.trim().isEmpty && itemData['oracle_text'] != null) {
      final rawOracle = itemData['oracle_text'].toString();
      if (rawOracle.contains(' // ') || rawOracle.contains('//')) {
        final sep = rawOracle.contains(' // ') ? ' // ' : '//';
        final parts = rawOracle.split(sep);
        oracleText = ((isCurrent && _isFlipped) && parts.length > 1)
            ? parts[1].trim()
            : parts[0].trim();
      } else {
        oracleText = rawOracle;
      }
    }
    if (oracleText.trim().isEmpty && cardFaces.isNotEmpty) {
      if ((isCurrent && _isFlipped) && cardFaces.length > 1) {
        oracleText = (cardFaces[1]['oracle_text'] as String?)?.trim() ?? '';
      } else {
        oracleText = (cardFaces[0]['oracle_text'] as String?)?.trim() ?? '';
      }
      if (oracleText.trim().isEmpty) {
        oracleText = cardFaces
            .map((f) => (f['oracle_text'] as String?)?.trim() ?? '')
            .where((t) => t.isNotEmpty)
            .join('\n\n//\n\n');
      }
    }

    final rarity = itemData['rarity']?.toString() ?? '';
    final power = activeFace?['power']?.toString() ?? itemData['power']?.toString();
    final toughness = activeFace?['toughness']?.toString() ?? itemData['toughness']?.toString();
    final loyalty = activeFace?['loyalty']?.toString() ?? itemData['loyalty']?.toString();
    final rulings = itemData['rulings']?.toString() ?? itemData['use_cases']?.toString() ?? '';

    String flavorText = activeFace?['flavor_text']?.toString() ?? '';
    if (flavorText.trim().isEmpty && itemData['flavor_text'] != null) {
      final rawFlavor = itemData['flavor_text'].toString();
      if (rawFlavor.contains(' // ') || rawFlavor.contains('//')) {
        final sep = rawFlavor.contains(' // ') ? ' // ' : '//';
        final parts = rawFlavor.split(sep);
        flavorText = ((isCurrent && _isFlipped) && parts.length > 1)
            ? parts[1].trim()
            : parts[0].trim();
      } else {
        flavorText = rawFlavor;
      }
    }

    final rawKeywords = itemData['keywords'];
    final keywordsList = rawKeywords is List ? rawKeywords : null;
    final isMtg = item.collectionType.toLowerCase() == 'mtg' ||
        item.collectionType.toLowerCase().contains('magic');
    final mechanics = isMtg
        ? MtgKeywordGlossary.extractKeywords(
            keywords: keywordsList,
            oracleText: oracleText,
          )
        : const <String>[];

    final effectivePrice = (isCurrent && _previewCandidate != null && _previewCandidate!.marketPrice > 0)
        ? _previewCandidate!.marketPrice
        : (item.currentMarketPrice > 0
            ? item.currentMarketPrice
            : VaultPricingHelper.extractFromDynamicData(itemData));
    final delta = (effectivePrice - item.acquiredPrice) * item.quantity;
    final pct = item.acquiredPrice > 0
        ? ((effectivePrice - item.acquiredPrice) / item.acquiredPrice) * 100
        : 0.0;
    final isProfit = delta >= 0;
    final isOwned = item.quantity > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 250;
        return Column(
          children: [
            // Sheet Header Bar
            Padding(
              padding: EdgeInsets.fromLTRB(20, isCompact ? 2 : 4, 12, isCompact ? 2 : 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.flavorName != null && item.flavorName!.isNotEmpty
                                ? item.flavorName!
                                : (activeFace?['name']?.toString() ?? item.name),
                            style: AppTypography.heading1.copyWith(fontSize: isCompact ? 14 : 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: isCompact ? 1 : 2),
                        isCompact
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.flavorName != null && item.flavorName!.isNotEmpty) ...[
                                      Text(
                                        '[${item.name}]',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.accentCyan,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                    ] else if (hasMultiple && activeFace != null) ...[
                                      Text(
                                        'Face ${(isCurrent && _isFlipped) ? 2 : 1}/${cardFaces.length}',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.accentCyan,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                    ],
                                    Text(
                                      item.setOrSeries,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (rarity.isNotEmpty) ...[
                                      const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
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
                              )
                            : Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  if (item.flavorName != null && item.flavorName!.isNotEmpty) ...[
                                    Text(
                                      '[${item.name}]',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.accentCyan,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                  ] else if (hasMultiple && activeFace != null) ...[
                                    Text(
                                      'Face ${(isCurrent && _isFlipped) ? 2 : 1}/${cardFaces.length}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.accentCyan,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                  ],
                                  Text(
                                    item.setOrSeries,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (rarity.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
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
                    padding: isCompact ? EdgeInsets.zero : const EdgeInsets.all(8.0),
                    constraints: isCompact ? const BoxConstraints() : null,
                    icon: Icon(Icons.close, color: AppColors.textSecondary, size: isCompact ? 18 : 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

            // Segmented Tab Control: [ Details | Values ]
            _buildSegmentedTabControl(isCompact: isCompact),

        // Content Area based on _selectedTab
        Expanded(
          child: _selectedTab == CardDetailTab.details
              ? _buildDetailsTab(
                  context,
                  item,
                  itemData,
                  cardFaces,
                  isAdventure,
                  hasMultiple,
                  activeFace,
                  manaCost,
                  typeLine,
                  oracleText,
                  flavorText,
                  rarity,
                  power,
                  toughness,
                  loyalty,
                  rulings,
                  mechanics,
                  effectivePrice,
                  delta,
                  pct,
                  isProfit,
                  isOwned,
                  isCurrent,
                  activeScrollController,
                )
              : _buildValuesTab(
                  context,
                  item,
                  effectivePrice,
                  delta,
                  pct,
                  isProfit,
                  isCurrent,
                  activeScrollController,
                ),
        ),
      ],
    );
  },
);
  }

  Widget _buildSegmentedTabControl({bool isCompact = false}) {
    final isPrivacyActive = _isPrivacyMode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isCompact ? 2 : 4),
      child: Container(
        key: const Key('card_detail_segmented_control'),
        height: isCompact ? 28 : 38,
        padding: EdgeInsets.all(isCompact ? 2 : 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('card_detail_tab_details'),
                onTap: () => setState(() => _selectedTab = CardDetailTab.details),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _selectedTab == CardDetailTab.details
                        ? AppColors.surfaceHighlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Details',
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 13,
                        fontWeight: _selectedTab == CardDetailTab.details
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == CardDetailTab.details
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                key: const Key('card_detail_tab_values'),
                onTap: () => setState(() => _selectedTab = CardDetailTab.valuesTab),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _selectedTab == CardDetailTab.valuesTab
                        ? AppColors.surfaceHighlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Values',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 13,
                            fontWeight: _selectedTab == CardDetailTab.valuesTab
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedTab == CardDetailTab.valuesTab
                                ? AppColors.accentCyan
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (isPrivacyActive) ...[
                          SizedBox(width: isCompact ? 2 : 4),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: isCompact ? 11 : 13,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(
    BuildContext context,
    VaultItem item,
    Map<String, dynamic> itemData,
    List<Map<String, dynamic>> cardFaces,
    bool isAdventure,
    bool hasMultiple,
    Map<String, dynamic>? activeFace,
    String manaCost,
    String typeLine,
    String oracleText,
    String flavorText,
    String rarity,
    String? power,
    String? toughness,
    String? loyalty,
    String rulings,
    List<String> mechanics,
    double effectivePrice,
    double delta,
    double pct,
    bool isProfit,
    bool isOwned,
    bool isCurrent,
    ScrollController? activeScrollController,
  ) {
    final artistName = itemData['artist']?.toString() ??
        activeFace?['artist']?.toString() ??
        '';

    return ListView(
      key: PageStorageKey('card_detail_list_${item.id}'),
      controller: activeScrollController,
      primary: false,
      cacheExtent: 3000,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        // Card Artwork & Core Metadata Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardArtwork(item, isCurrent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLine,
                    style: AppTypography.heading2.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 6),
                  if (manaCost.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: ManaCostBar(
                        manaCost: manaCost,
                        symbolSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        VaultPricingHelper.formatMarketHeaderLabel(
                          effectivePrice,
                          currency: _baseCurrency,
                          isPrivacyMode: _isPrivacyMode,
                        ),
                        style: const TextStyle(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (power != null && toughness != null && power.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'P/T: $power / $toughness',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Loyalty: $loyalty',
                          style: const TextStyle(
                            color: AppColors.accentViolet,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Unowned Catalog Card Action Bar
        if (!isOwned) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: isCurrent ? const Key('card_detail_add_to_vault') : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Add to Vault / Inbox',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ),
                onPressed: isCurrent ? _addToVault : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Section 1: Oracle & Rules Text
        Wrap(
          key: const Key('section_oracle_rules'),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildSectionHeader(Icons.auto_stories_rounded, 'Oracle Rules Text'),
            if (hasMultiple && cardFaces.length > 1 && isCurrent && !isAdventure)
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
              ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: isAdventure
              ? _buildAdventureOracleContentForItem(item, itemData, oracleText, flavorText)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasMultiple && activeFace != null && cardFaces.length > 1) ...[
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
                              (isCurrent && _isFlipped) ? Icons.flip_to_back : Icons.flip_to_front,
                              size: 13,
                              color: AppColors.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${activeFace['name'] ?? ((isCurrent && _isFlipped) ? 'Back Face' : 'Front Face')} — ${activeFace['type_line'] ?? ''}',
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
                    ManaText(
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

        // Card Mechanics & Rulings (Expandable Accordion)
        _buildCardMechanicsAndRulings(
          mechanics,
          isCurrent ? _cachedRulings : const [],
          isCurrent ? _isLoadingRulings : false,
        ),

        // Official Rulings Clarifications
        if ((isCurrent ? _cachedRulings.isEmpty : true) && rulings.isNotEmpty) ...[
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
            child: ManaText(
              rulings,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],

        // Section 2: Collection & Portfolio Metrics
        if (isOwned) ...[
          const SizedBox(height: 8),
          Wrap(
            key: const Key('section_portfolio_metrics'),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildSectionHeader(Icons.analytics_outlined, 'Collection & Portfolio Metrics'),
              OutlinedButton.icon(
                key: const Key('card_detail_switch_printing_button'),
                icon: const Icon(Icons.sync_alt, size: 14, color: AppColors.accentCyan),
                label: const Text('Switch Printing', style: TextStyle(fontSize: 12, color: AppColors.accentCyan)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.accentCyan),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => SwitchPrintingModal.show(context, item),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMetricBox('Owned Copies', '${item.quantity}x', AppColors.textPrimary),
                    const SizedBox(width: 8),
                    _buildMetricBox('Condition', item.condition, AppColors.accentCyan),
                    const SizedBox(width: 8),
                    _buildMetricBox(
                      'Language',
                      (itemData['lang'] ?? itemData['language'] ?? 'EN').toString().toUpperCase(),
                      AppColors.accentEmerald,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricBox(
                      'Treatment',
                      _extractTreatment(item, itemData),
                      AppColors.accentVioletLight,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMetricBox(
                      'Acquisition Price',
                      VaultPricingHelper.formatAmount(
                        item.purchasePrice ?? item.acquiredPrice,
                        currency: _baseCurrency,
                        isPrivacyMode: _isPrivacyMode,
                        allowZero: true,
                      ),
                      AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricBox(
                      'Profit / Loss',
                      VaultPricingHelper.formatReturn(
                        delta,
                        pct,
                        currency: _baseCurrency,
                        isPrivacyMode: _isPrivacyMode,
                        amountFirst: true,
                      ),
                      isProfit ? AppColors.accentEmerald : AppColors.accentRose,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Wrap(
            key: const Key('section_portfolio_metrics'),
            children: [
              _buildSectionHeader(Icons.analytics_outlined, 'Collection & Portfolio Metrics'),
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
            child: Row(
              children: [
                _buildMetricBox('Owned Copies', '0x', AppColors.textMuted),
                const SizedBox(width: 10),
                _buildMetricBox('Status', 'Catalog Item', AppColors.accentCyan),
                const SizedBox(width: 10),
                _buildMetricBox(
                  'Market Price',
                  VaultPricingHelper.formatAmount(
                    effectivePrice,
                    currency: _baseCurrency,
                    isPrivacyMode: _isPrivacyMode,
                    fallback: 'Unlisted',
                  ),
                  AppColors.accentAmber,
                ),
              ],
            ),
          ),
        ],

        // Section 3: Physical Provenance
        _buildSectionHeader(Icons.inventory_2_outlined, 'Physical Provenance'),
        Container(
          key: const Key('section_physical_provenance'),
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Protection Status Dropdown
              const Text(
                'Protection Status',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const Key('card_detail_protection_status_dropdown'),
                isExpanded: true,
                initialValue: const [
                  'Sleeved',
                  'Double Sleeved',
                  'Perfect Fit',
                  'Penny Sleeve',
                  'Toploader',
                  'Magnetic One-Touch',
                  'Graded Slab',
                  'Raw',
                ].contains(item.protectionStatus)
                    ? item.protectionStatus
                    : 'Sleeved',
                dropdownColor: AppColors.surfaceRaised,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
                items: const [
                  'Sleeved',
                  'Double Sleeved',
                  'Perfect Fit',
                  'Penny Sleeve',
                  'Toploader',
                  'Magnetic One-Touch',
                  'Graded Slab',
                  'Raw',
                ].map((s) => DropdownMenuItem(
                      value: s,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(s),
                      ),
                    )).toList(),
                onChanged: isCurrent ? (val) {
                  if (val != null) _updateProtectionStatus(val);
                } : null,
              ),
              const SizedBox(height: 12),

              // Binder & Slot Coordinates
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Binder Page',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          key: const Key('card_detail_binder_page_input'),
                          controller: _binderPageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Page #',
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
                          onSubmitted: isCurrent ? (_) => _saveBinderCoordinates() : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Binder Slot',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          key: const Key('card_detail_binder_slot_input'),
                          controller: _binderSlotController,
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Slot (e.g. Slot: A3)',
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
                          onSubmitted: isCurrent ? (_) => _saveBinderCoordinates() : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notes & Strategy Tips
              const Text(
                'Personal Notes & Strategy Tips',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              isCurrent
                  ? Column(
                      children: [
                        TextField(
                          key: const Key('card_detail_notes_input'),
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter combos, strategy tips, or personal notes...',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: TextButton.icon(
                                key: const Key('card_detail_save_notes_button'),
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
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      item.notes?.isNotEmpty == true
                          ? item.notes!
                          : (item.personalNotes?.isNotEmpty == true
                              ? item.personalNotes!
                              : 'No personal notes recorded.'),
                      style: TextStyle(
                        color: (item.notes?.isNotEmpty == true || item.personalNotes?.isNotEmpty == true)
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
            ],
          ),
        ),

        // Section 4: Acquisition Tracking
        _buildSectionHeader(Icons.receipt_long_outlined, 'Acquisition Tracking'),
        Container(
          key: const Key('section_acquisition_tracking'),
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Obtained Row
              OutlinedButton.icon(
                key: const Key('card_detail_date_obtained_button'),
                icon: const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.accentCyan),
                label: Text(
                  'Date Obtained: ${_formatDate(item.dateObtained ?? item.acquiredDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.accentCyan),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: isCurrent ? _pickDateObtained : null,
              ),
              const SizedBox(height: 12),

              // Acquired Price & P/L Metrics Row
              Row(
                children: [
                  _buildMetricBox(
                    'Acquired Price',
                    VaultPricingHelper.formatAmount(
                      item.purchasePrice ?? item.acquiredPrice,
                      currency: _baseCurrency,
                      isPrivacyMode: _isPrivacyMode,
                      allowZero: true,
                    ),
                    AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricBox(
                    'Profit / Loss',
                    VaultPricingHelper.formatReturn(
                      delta,
                      pct,
                      currency: _baseCurrency,
                      isPrivacyMode: _isPrivacyMode,
                      amountFirst: true,
                    ),
                    isProfit ? AppColors.accentEmerald : AppColors.accentRose,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Purchase Price Input
              const Text(
                'Edit Purchase Price',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('card_detail_purchase_price_input'),
                controller: _purchasePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  prefixText: '${_baseCurrency.symbol} ',
                  prefixStyle: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700),
                  hintText: '0.00',
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
                onSubmitted: isCurrent ? (val) => _updatePurchasePrice(val) : null,
              ),
            ],
          ),
        ),

        // Section 5: Metadata & Pedigree
        _buildSectionHeader(Icons.verified_outlined, 'Metadata & Pedigree'),
        Container(
          key: const Key('section_metadata_pedigree'),
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (artistName.isNotEmpty) ...[
                OutlinedButton.icon(
                  key: const Key('card_detail_artist_filter_button'),
                  icon: const Icon(Icons.palette_outlined, size: 14, color: AppColors.accentCyan),
                  label: Text('Artist: $artistName', style: const TextStyle(fontSize: 12, color: AppColors.accentCyan)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.accentCyan),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  onPressed: () {
                    ref.read(vaultSearchQueryProvider.notifier).state = artistName;
                    Navigator.of(context).pop();
                  },
                ),
              ],
              _buildFrameBadges(itemData),
            ],
          ),
        ),

        // Section 6: Deck History & Associations
        Wrap(
          key: const Key('section_deck_history'),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildSectionHeader(Icons.view_carousel_rounded, 'Deck History & Tags'),
            OutlinedButton.icon(
              key: const Key('button_add_edit_in_decks'),
              icon: const Icon(Icons.playlist_add_rounded, size: 14, color: AppColors.accentVioletLight),
              label: const Text('Add / Edit in Decks', style: TextStyle(fontSize: 12, color: AppColors.accentVioletLight)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: AppColors.accentVioletLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () => MultiDeckAllocationSheet.show(context, _currentItem),
            ),
          ],
        ),
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
              if (isCurrent) ...[
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
              ] else ...[
                if ((itemData['deck_history'] as List?)?.isEmpty ?? true)
                  const Text(
                    'No deck history recorded yet.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ((itemData['deck_history'] as List?) ?? []).map((deck) {
                      return Chip(
                        label: Text(deck.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        backgroundColor: AppColors.surfaceHighlight,
                      );
                    }).toList(),
                  ),
              ],
            ],
          ),
        ),

        // Deck Gear Section (Deck Scope Only)
        if (widget.deckId != null || widget.deck != null) ...[
          _buildSectionHeader(Icons.backpack_outlined, 'Deck Gear & Physical Checklist'),
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 18),
            child: DeckGearSection(
              deckId: widget.deckId ?? widget.deck!.id,
              deck: widget.deck,
              deckItems: _items,
            ),
          ),
        ],

        // Section 7: Variant & Price Chart Component
        const SizedBox(height: 8),
        VariantPriceChart(
          item: item,
          isPrivacyMode: _isPrivacyMode,
          enableOnlineFetch: widget.fetchOnlinePrintings,
          onPrintingSelected: isCurrent
              ? (candidate) {
                  setState(() {
                    _previewCandidate = candidate;
                  });
                }
              : null,
          onPrintingChanged: (updated) {
            setState(() {
              _currentItem = updated;
              _previewCandidate = null;
              if (_items.isNotEmpty && _currentIndex < _items.length) {
                _items[_currentIndex] = updated;
              }
              if (updated.dynamicData.isNotEmpty) {
                try {
                  _dynamicData = jsonDecode(updated.dynamicData) as Map<String, dynamic>;
                } catch (e, stackTrace) {
                  debugPrint('[CardDetailSheet] Failed decoding updated dynamicData: $e\n$stackTrace');
                }
              }
            });
          },
        ),
        const SizedBox(height: 8),

        // Section 8: Format Legalities (moved to the very bottom, below Variant Chart)
        _buildFormatLegalities(),
      ],
    );
  }

  bool _isReserved(VaultItem item) {
    if (_dynamicData.containsKey('reserved')) {
      return _dynamicData['reserved'] == true;
    }
    return false;
  }

  double _extract52WeekLow(VaultItem item, double effectivePrice) {
    if (_dynamicData.containsKey('52_week_low')) {
      final val = (_dynamicData['52_week_low'] as num?)?.toDouble();
      if (val != null && val > 0) return val;
    }
    return effectivePrice > 0 ? (effectivePrice * 0.75) : 0.0;
  }

  double _extract52WeekHigh(VaultItem item, double effectivePrice) {
    if (_dynamicData.containsKey('52_week_high')) {
      final val = (_dynamicData['52_week_high'] as num?)?.toDouble();
      if (val != null && val > 0) return val;
    }
    return effectivePrice > 0 ? (effectivePrice * 1.35) : 0.0;
  }

  double _extractBaseNonFoil(VaultItem item, double effectivePrice) {
    final prices = _dynamicData['prices'];
    if (prices is Map && prices['usd'] != null) {
      final p = double.tryParse(prices['usd'].toString());
      if (p != null && p > 0.02) return p;
    }
    return effectivePrice > 0 ? effectivePrice : 10.0;
  }

  double _extractBaseFoil(VaultItem item, double effectivePrice) {
    final prices = _dynamicData['prices'];
    if (prices is Map && prices['usd_foil'] != null) {
      final p = double.tryParse(prices['usd_foil'].toString());
      if (p != null && p > 0.02) return p;
    }
    final nonFoil = _extractBaseNonFoil(item, effectivePrice);
    return nonFoil * 1.4;
  }

  double _extractBaseEtched(VaultItem item, double effectivePrice) {
    final prices = _dynamicData['prices'];
    if (prices is Map && prices['usd_etched'] != null) {
      final p = double.tryParse(prices['usd_etched'].toString());
      if (p != null && p > 0.02) return p;
    }
    final foil = _extractBaseFoil(item, effectivePrice);
    return foil * 1.1;
  }

  String _extractOwnedFinish(VaultItem item) {
    final finishes = _dynamicData['finishes'];
    if (finishes is List) {
      if (finishes.contains('etched')) return 'etched';
      if (finishes.contains('foil') && !finishes.contains('nonfoil')) return 'foil';
    }
    return 'non_foil';
  }

  Widget _buildValuesTab(
    BuildContext context,
    VaultItem item,
    double effectivePrice,
    double delta,
    double pct,
    bool isProfit,
    bool isCurrent,
    ScrollController? activeScrollController,
  ) {
    if (_isPrivacyMode) {
      return ListView(
        key: const Key('card_detail_values_locked_container'),
        controller: activeScrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: const [
          LockedValuesView(),
        ],
      );
    }

    return ListView(
      key: PageStorageKey('card_detail_values_${item.id}'),
      controller: activeScrollController,
      primary: false,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        // Valuation Summary Card with Market Valuation header & Live Sync badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Market Valuation',
                        key: const Key('market_valuation_header'),
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FreshnessBadgeWidget(
                            lastUpdated: item.lastPriceUpdate,
                            animate: false,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            key: const Key('live_sync_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentCyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync, size: 12, color: AppColors.accentCyan),
                                SizedBox(width: 4),
                                Text(
                                  'Live Sync',
                                  style: TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Price',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            VaultPricingHelper.formatAmount(
                              effectivePrice,
                              currency: _baseCurrency,
                              isPrivacyMode: false,
                            ),
                            style: const TextStyle(
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cost Basis',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            VaultPricingHelper.formatAmount(
                              item.purchasePrice ?? item.acquiredPrice,
                              currency: _baseCurrency,
                              isPrivacyMode: false,
                              allowZero: true,
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'P&L Return',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            VaultPricingHelper.formatReturn(
                              delta,
                              pct,
                              currency: _baseCurrency,
                              isPrivacyMode: false,
                              amountFirst: true,
                            ),
                            style: TextStyle(
                              color: isProfit ? AppColors.accentEmerald : AppColors.accentRose,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
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

        const SizedBox(height: 16),

        // 2. Interactive Multi-Line Price Trends Chart
        _buildSectionHeader(Icons.show_chart_rounded, 'Market Price Trends & History'),
        const SizedBox(height: 8),
        InteractiveMultiLineChart(
          fallbackCurrentPrice: effectivePrice > 0 ? effectivePrice : 15.0,
          isPrivacyMode: false,
        ),

        const SizedBox(height: 16),

        // 3. Cost Basis & P&L Widget
        _buildSectionHeader(Icons.account_balance_wallet_outlined, 'Cost Basis & P&L Return'),
        const SizedBox(height: 8),
        CostBasisPnLWidget(
          purchasePrice: (item.purchasePrice ?? item.acquiredPrice) > 0
              ? (item.purchasePrice ?? item.acquiredPrice)
              : null,
          marketPrice: effectivePrice,
          quantity: item.quantity > 0 ? item.quantity : 1,
          currency: _baseCurrency,
          isPrivacyMode: false,
        ),

        const SizedBox(height: 16),

        // 4. Liquidity & Reality Check Widget
        _buildSectionHeader(Icons.water_drop_outlined, 'Liquidity & Reality Check'),
        const SizedBox(height: 8),
        LiquidityRealityCheckWidget(
          marketPrice: effectivePrice,
          quantity: item.quantity > 0 ? item.quantity : 1,
          isReservedList: _isReserved(item),
          currency: _baseCurrency,
          isPrivacyMode: false,
        ),

        const SizedBox(height: 16),

        // 5. 52-Week Range Bar
        _buildSectionHeader(Icons.straighten_rounded, '52-Week Price Range'),
        const SizedBox(height: 8),
        FiftyTwoWeekRangeBar(
          low52: _extract52WeekLow(item, effectivePrice),
          high52: _extract52WeekHigh(item, effectivePrice),
          currentPrice: effectivePrice,
          currency: _baseCurrency,
          isPrivacyMode: false,
        ),

        const SizedBox(height: 16),

        // 6. Condition & Treatment Matrix Widget
        _buildSectionHeader(Icons.grid_view_rounded, 'Condition & Finish Matrix'),
        const SizedBox(height: 8),
        ConditionTreatmentMatrixWidget(
          baseNonFoil: _extractBaseNonFoil(item, effectivePrice),
          baseFoil: _extractBaseFoil(item, effectivePrice),
          baseEtched: _extractBaseEtched(item, effectivePrice),
          ownedCondition: item.condition.isNotEmpty ? item.condition : 'NM',
          ownedFinish: _extractOwnedFinish(item),
          currency: _baseCurrency,
          isPrivacyMode: false,
        ),

        const SizedBox(height: 16),

        // 7. Multi-Market Spread Table
        _buildSectionHeader(Icons.table_chart_outlined, 'Multi-Market Spread'),
        const SizedBox(height: 8),
        MarketSpreadTableWidget(
          baselinePrice: effectivePrice > 0 ? effectivePrice : 15.0,
          currency: _baseCurrency,
          isPrivacyMode: false,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _extractTreatment(VaultItem item, Map<String, dynamic> itemData) {
    final finishes = itemData['finishes'];
    if (finishes is List) {
      if (finishes.contains('etched')) return 'Etched Foil';
      if (finishes.contains('foil') && !finishes.contains('nonfoil')) return 'Foil';
    }
    final frameEffects = itemData['frame_effects'];
    if (frameEffects is List && frameEffects.contains('showcase')) return 'Showcase';
    if (itemData['border_color'] == 'borderless') return 'Borderless';
    if (itemData['frame'] == '1993' || itemData['frame'] == '1997') return 'Retro Frame';
    if (itemData['full_art'] == true) return 'Full Art';
    if (item.isGraded) return 'Graded Slab';
    return 'Standard';
  }

  Widget _buildFrameBadges(Map<String, dynamic> itemData) {
    final badges = <String>[];
    final frameEffects = itemData['frame_effects'] as List?;
    if (itemData['border_color'] == 'borderless') badges.add('Borderless');
    if (itemData['frame'] == '1993' || itemData['frame'] == '1997') badges.add('Retro Frame');
    if (frameEffects != null && frameEffects.contains('showcase')) badges.add('Showcase');
    if (frameEffects != null && frameEffects.contains('extendedart')) badges.add('Extended Art');
    if (itemData['full_art'] == true) badges.add('Full Art');
    if (itemData['promo'] == true) badges.add('Promo');
    if (itemData['textless'] == true) badges.add('Textless');
    final finishes = itemData['finishes'] as List?;
    if (finishes != null && finishes.contains('etched')) badges.add('Etched Foil');

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badges.map((badge) {
          final slug = badge.toLowerCase().replaceAll(' ', '_');
          return Container(
            key: Key('frame_badge_$slug'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceBorderSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _updateProtectionStatus(String newStatus) async {
    final dao = ref.read(vaultDaoProvider);
    await dao.updateItemCardDetails(
      id: _currentItem.id,
      protectionStatus: newStatus,
    );
    if (mounted) {
      setState(() {
        _currentItem = _currentItem.copyWith(protectionStatus: Value(newStatus));
        if (_currentIndex < _items.length) {
          _items[_currentIndex] = _currentItem;
        }
      });
    }
  }

  Future<void> _saveBinderCoordinates() async {
    final page = int.tryParse(_binderPageController.text.trim());
    final slot = _binderSlotController.text.trim();
    final dao = ref.read(vaultDaoProvider);
    await dao.updateItemCardDetails(
      id: _currentItem.id,
      binderPage: page,
      binderSlot: slot.isNotEmpty ? slot : null,
    );
    if (mounted) {
      setState(() {
        _currentItem = _currentItem.copyWith(
          binderPage: Value(page),
          binderSlot: Value(slot.isNotEmpty ? slot : null),
        );
        if (_currentIndex < _items.length) {
          _items[_currentIndex] = _currentItem;
        }
      });
    }
  }

  Future<void> _pickDateObtained() async {
    final initialDate = _currentItem.dateObtained ?? _currentItem.acquiredDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1993),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final dao = ref.read(vaultDaoProvider);
      await dao.updateItemCardDetails(
        id: _currentItem.id,
        dateObtained: picked,
        acquiredDate: picked,
      );
      if (mounted) {
        setState(() {
          _currentItem = _currentItem.copyWith(
            dateObtained: Value(picked),
            acquiredDate: picked,
          );
          if (_currentIndex < _items.length) {
            _items[_currentIndex] = _currentItem;
          }
        });
      }
    }
  }

  Future<void> _updatePurchasePrice(String value) async {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed >= 0) {
      final dao = ref.read(vaultDaoProvider);
      await dao.updateItemCardDetails(
        id: _currentItem.id,
        purchasePrice: parsed,
        acquiredPrice: parsed,
      );
      if (mounted) {
        setState(() {
          _currentItem = _currentItem.copyWith(
            purchasePrice: Value(parsed),
            acquiredPrice: parsed,
          );
          if (_currentIndex < _items.length) {
            _items[_currentIndex] = _currentItem;
          }
        });
      }
    }
  }

  Widget _buildCardArtwork(VaultItem item, bool isCurrent) {
    if (!isCurrent) {
      final frontUrl = item.imageUrl.isNotEmpty ? item.imageUrl : '';
      return Hero(
        key: Key('card_artwork_${item.id}'),
        tag: 'card_artwork_${item.id}',
        child: _buildCardFaceContainer(frontUrl, cardName: item.name),
      );
    }

    final hasFlip = _hasFlipArt;

    final artwork = GestureDetector(
      onTap: hasFlip ? _toggleFlip : _openFullScreenViewer,
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
                    child: _buildCardFaceContainer(currentUrl, cardName: item.name),
                  )
                : _buildCardFaceContainer(currentUrl, cardName: item.name),
          );
        },
      ),
    );

    return Hero(
      key: Key('card_artwork_${item.id}'),
      tag: 'card_artwork_${item.id}',
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

  Widget _buildCardFaceContainer(String imageUrl, {String? cardName}) {
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
              errorBuilder: (_, _, _) => _buildPlaceholderArt(cardName: cardName),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                );
              },
            )
          : _buildPlaceholderArt(cardName: cardName),
    );
  }

  Widget _buildPlaceholderArt({String? cardName}) {
    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(
            cardName ?? _currentItem.name,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.accentCyan),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: AppTypography.heading2.copyWith(fontSize: 14),
            ),
          ),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatLegalities() {
    final formats = ['Standard', 'Pioneer', 'Modern', 'Legacy', 'Vintage', 'Commander', 'Pauper'];
    return Column(
      key: const Key('section_format_legalities'),
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

  Widget _buildAdventureOracleContentForItem(
    VaultItem item,
    Map<String, dynamic> data,
    String oracleText,
    String flavorText,
  ) {
    final faces = _getCardFacesForItem(item, data);
    Map<String, dynamic> face0 = {};
    Map<String, dynamic> face1 = {};

    if (faces.length >= 2) {
      face0 = faces[0];
      face1 = faces[1];
    } else {
      final names = item.name.contains(' // ')
          ? item.name.split(' // ')
          : item.name.split('//');
      final oracles = oracleText.contains(' // ')
          ? oracleText.split(' // ')
          : oracleText.split('//');
      face0 = {
        'name': names[0].trim(),
        'type_line': data['type_line']?.toString() ?? 'Creature',
        'mana_cost': data['mana_cost']?.toString() ?? '',
        'oracle_text': oracles[0].trim(),
        'power': data['power'],
        'toughness': data['toughness'],
      };
      face1 = {
        'name': names.length > 1 ? names[1].trim() : 'Adventure Spell',
        'type_line': 'Instant — Adventure',
        'mana_cost': '',
        'oracle_text': oracles.length > 1 ? oracles[1].trim() : '',
      };
    }

    final name0 = face0['name']?.toString() ?? item.name;
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
                child: ManaCostBar(
                  manaCost: mana0,
                  symbolSize: 13.0,
                  fallbackTextStyle: const TextStyle(
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
          ManaText(
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
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
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
                child: ManaCostBar(
                  manaCost: mana1,
                  symbolSize: 13.0,
                  fallbackTextStyle: const TextStyle(
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
          ManaText(
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

              // Scryfall rulings expandable accordion
              if (rulings.isNotEmpty) ...[
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const Key('card_detail_rulings_accordion'),
                    initiallyExpanded: true,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.gavel_rounded, size: 16, color: AppColors.accentAmber),
                    title: Text(
                      'Official Rulings (${rulings.length})',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    children: [
                      const SizedBox(height: 6),
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
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    rulings[i].publishedAt,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                        ],
                        ManaText(
                          rulings[i].comment,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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

  Future<void> _openFullScreenViewer() async {
    final returnedIndex = await FullScreenCardViewer.show(
      context,
      _currentItem,
      items: _items,
      initialIndex: _currentIndex,
      onPageChanged: (newIdx) {
        if (newIdx != _currentIndex && newIdx >= 0 && newIdx < _items.length) {
          if (_pageController.hasClients && _pageController.page?.round() != newIdx) {
            _pageController.jumpToPage(newIdx);
          }
          _onPageChanged(newIdx);
        }
      },
    );

    if (returnedIndex != null && mounted) {
      if (returnedIndex != _currentIndex && returnedIndex >= 0 && returnedIndex < _items.length) {
        if (_pageController.hasClients && _pageController.page?.round() != returnedIndex) {
          _pageController.jumpToPage(returnedIndex);
        }
        _onPageChanged(returnedIndex);
      }
    }
  }

  Future<void> _showAddToDeckDialog() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return _AddToDeckDialogContent(
          currentItem: _currentItem,
          deckHistory: _deckHistory,
          parentContext: context,
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
              ref.read(privacyModeProvider)
                  ? 'Market Value: ****'
                  : (_effectiveMarketPrice > 0
                      ? 'Market Value: \$${_effectiveMarketPrice.toStringAsFixed(2)}'
                      : 'Market Value: Unavailable'),
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
          if (_currentIndex < _items.length) {
            _items[_currentIndex] = finalItem;
          }
          _notesController.text = finalItem.personalNotes ?? '';
          _parseDynamicData();
        });
      }
    }
  }
}

class _AddToDeckDialogContent extends ConsumerStatefulWidget {
  final VaultItem currentItem;
  final List<String> deckHistory;
  final BuildContext parentContext;

  const _AddToDeckDialogContent({
    required this.currentItem,
    required this.deckHistory,
    required this.parentContext,
  });

  @override
  ConsumerState<_AddToDeckDialogContent> createState() => _AddToDeckDialogContentState();
}

class _AddToDeckDialogContentState extends ConsumerState<_AddToDeckDialogContent> {
  late final TextEditingController _customDeckController;

  @override
  void initState() {
    super.initState();
    _customDeckController = TextEditingController();
  }

  @override
  void dispose() {
    _customDeckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(vaultDaoProvider);
    final decksAsync = ref.watch(deckListProvider);
    final allocationsAsync = ref.watch(cardDeckAllocationsProvider(widget.currentItem.id));
    final allocations = allocationsAsync.asData?.value ?? <String, int>{};

    final dbDecks = decksAsync.asData?.value ?? <Deck>[];
    final decks = dbDecks.isEmpty ? MockDeckData.defaultDecks : dbDecks;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Add Card to Deck',
                  style: AppTypography.heading2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: decks.map((deck) {
              final allocatedQty = allocations[deck.id] ?? 0;
              final inDeck = allocatedQty > 0 || widget.deckHistory.contains(deck.name);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.style_rounded, color: AppColors.accentVioletLight, size: 20),
                title: Text(deck.name, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
                trailing: inDeck
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 20)
                    : const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan, size: 20),
                onTap: () async {
                  final availableQty = await dao.getAvailableQuantity(widget.currentItem.id);

                  if (availableQty < 1) {
                    if (!context.mounted) return;
                    final decksAssigned = await dao.getDecksUsingItem(widget.currentItem.id);
                    if (!context.mounted) return;

                    await ConflictResolutionModal.show(
                      context: context,
                      cardName: widget.currentItem.name,
                      deckNames: decksAssigned,
                      onMovePhysical: () async {
                        await dao.moveCardToDeck(widget.currentItem.id, deck.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      onAddAsProxy: () async {
                        await dao.addCardToDeck(deck.id, widget.currentItem.id, isProxy: true);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    );
                    return;
                  }

                  await dao.addCardToDeck(deck.id, widget.currentItem.id, isProxy: false);
                  if (context.mounted) Navigator.of(context).pop();
                  if (!widget.parentContext.mounted) return;
                  ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                    SnackBar(
                      content: Text('Added to "${deck.name}"'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customDeckController,
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
                  final name = _customDeckController.text.trim();
                  if (name.isNotEmpty) {
                    final dao = ref.read(vaultDaoProvider);
                    final availableQty = await dao.getAvailableQuantity(widget.currentItem.id);

                    if (availableQty < 1) {
                      if (!context.mounted) return;
                      final result = await showDialog<String>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          title: const Text('Inventory Conflict'),
                          content: const Text('You do not have enough available physical copies of this card. What would you like to do?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop('cancel'),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop('proxy'),
                              child: const Text('Add as Proxy'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop('move'),
                              child: const Text('Move physical card here'),
                            ),
                          ],
                        ),
                      );
                      if (result != 'proxy') return;
                      final newDeck = await dao.createDeck(name);
                      await dao.addCardToDeck(newDeck.id, widget.currentItem.id, isProxy: true);
                    } else {
                      final newDeck = await dao.createDeck(name);
                      await dao.addCardToDeck(newDeck.id, widget.currentItem.id, isProxy: false);
                    }

                    if (context.mounted) Navigator.of(context).pop();
                    if (!widget.parentContext.mounted) return;
                    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                      SnackBar(
                        content: Text('Created "$name" and added card'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

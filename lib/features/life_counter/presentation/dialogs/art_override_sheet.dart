// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import '../widgets/commander_art_backdrop.dart';

/// Modal bottom sheet allowing players to search and override their quadrant backdrop
/// with any Scryfall card art or a custom image URL (Feature 31).
///
/// Features:
/// - Scryfall card catalog live search with 300ms debouncing.
/// - Graceful offline fallback querying local `VaultDao` singles when offline.
/// - Double-faced card (DFC) face switching (Face 0 vs. Face 1 art crop).
/// - Direct custom image URL input tab with live validation.
/// - Live interactive backdrop preview widget rendering the selected art with
///   vignette shading and mock life total.
/// - "Apply Backdrop" confirmation and "Reset to Default" restoration actions.
class ArtOverrideSheet extends ConsumerStatefulWidget {
  /// The player's ID whose quadrant backdrop is being modified.
  final String playerId;

  /// The player's display name.
  final String playerName;

  /// The currently active art crop URL.
  final String? currentArtUrl;

  /// The original commander card name (if any).
  final String? initialCommanderName;

  /// Callback invoked when an art crop URL is confirmed.
  final void Function(String newArtCropUrl, String? cardName)? onArtSelected;

  /// Callback invoked when resetting to the original commander art crop.
  final VoidCallback? onResetDefault;

  /// Optional injected [ScryfallService] for testing / mocking.
  final ScryfallService? scryfallService;

  /// Optional injected [VaultDao] for testing / mocking.
  final VaultDao? vaultDao;

  const ArtOverrideSheet({
    super.key,
    required this.playerId,
    required this.playerName,
    this.currentArtUrl,
    this.initialCommanderName,
    this.onArtSelected,
    this.onResetDefault,
    this.scryfallService,
    this.vaultDao,
  });

  /// Displays the [ArtOverrideSheet] modal and returns the chosen art URL or null.
  static Future<String?> show(
    BuildContext context, {
    required String playerId,
    required String playerName,
    String? currentArtUrl,
    String? initialCommanderName,
    void Function(String newArtCropUrl, String? cardName)? onArtSelected,
    VoidCallback? onResetDefault,
    ScryfallService? scryfallService,
    VaultDao? vaultDao,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ArtOverrideSheet(
        playerId: playerId,
        playerName: playerName,
        currentArtUrl: currentArtUrl,
        initialCommanderName: initialCommanderName,
        onArtSelected: onArtSelected,
        onResetDefault: onResetDefault,
        scryfallService: scryfallService,
        vaultDao: vaultDao,
      ),
    );
  }

  @override
  ConsumerState<ArtOverrideSheet> createState() => _ArtOverrideSheetState();
}

class _ArtOverrideSheetState extends ConsumerState<ArtOverrideSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customUrlController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = [];

  String? _selectedArtUrl;
  String? _selectedCardName;
  int _selectedFaceIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedArtUrl = widget.currentArtUrl;
    _selectedCardName = widget.initialCommanderName;
    if (_selectedArtUrl != null && _selectedArtUrl!.isNotEmpty) {
      _customUrlController.text = _selectedArtUrl!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customUrlController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _executeSearch(trimmed);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final ScryfallService scryfall = widget.scryfallService ?? ref.read(scryfallServiceProvider);
    final VaultDao dao = widget.vaultDao ?? ref.read(vaultDaoProvider);

    try {
      // 1. Try Scryfall search API
      final results = await scryfall.searchCards(query, limit: 30);
      if (mounted) {
        if (results != null && results.isNotEmpty) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
          return;
        }
      }
    } catch (_) {
      // Fallback to local DB if Scryfall network request fails or is offline
    }

    try {
      // 2. Fallback to local catalog in SQLite
      final localItems = await dao.searchCatalogCards(
        query,
        collectionType: 'mtg',
        groupByOracleId: true,
        limit: 30,
      );

      final localResults = <Map<String, dynamic>>[];
      for (final item in localItems) {
        Map<String, dynamic> cardData = {
          'id': item.id,
          'name': item.name,
          'set': item.setOrSeries,
          'image_uris': {'art_crop': item.imageUrl, 'normal': item.imageUrl},
        };
        if (item.dynamicData.isNotEmpty) {
          try {
            final decoded = jsonDecode(item.dynamicData);
            if (decoded is Map<String, dynamic>) {
              cardData = decoded;
            }
          } catch (_) {}
        }
        localResults.add(cardData);
      }

      if (mounted) {
        setState(() {
          _searchResults = localResults;
          _isSearching = false;
          if (localResults.isEmpty) {
            _searchError = 'No cards found matching "$query"';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError = 'Search failed. Check your internet connection.';
        });
      }
    }
  }

  String? _extractArtCrop(Map<String, dynamic> card, [int faceIndex = 0]) {
    // 1. Check card_faces for DFCs / Adventures / Reversible
    if (card['card_faces'] is List && (card['card_faces'] as List).isNotEmpty) {
      final faces = card['card_faces'] as List;
      final safeIndex = faceIndex.clamp(0, faces.length - 1);
      final face = faces[safeIndex];
      if (face is Map && face['image_uris'] is Map) {
        return face['image_uris']['art_crop'] as String? ??
            face['image_uris']['normal'] as String?;
      }
    }

    // 2. Check top-level image_uris
    if (card['image_uris'] is Map) {
      return card['image_uris']['art_crop'] as String? ??
          card['image_uris']['normal'] as String?;
    }

    return null;
  }

  void _selectCard(Map<String, dynamic> card, [int faceIndex = 0]) {
    final art = _extractArtCrop(card, faceIndex);
    final name = card['name'] as String? ?? 'Card Art';
    setState(() {
      _selectedArtUrl = art;
      _selectedCardName = name;
      _selectedFaceIndex = faceIndex;
    });
  }

  void _applyOverride() {
    if (_selectedArtUrl != null && _selectedArtUrl!.isNotEmpty) {
      widget.onArtSelected?.call(_selectedArtUrl!, _selectedCardName);
      Navigator.of(context).pop(_selectedArtUrl);
    }
  }

  void _resetToDefault() {
    widget.onResetDefault?.call();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;

    return Container(
      key: const Key('art_override_sheet'),
      height: screenHeight * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF141820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customize Backdrop Art',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Player: ${widget.playerName}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('art_override_close_button'),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Live Backdrop Preview Box
          _buildLivePreviewBox(),

          // Tabs: [Scryfall Catalog | Custom URL]
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.search, size: 18), text: 'Scryfall Catalog'),
              Tab(icon: Icon(Icons.link, size: 18), text: 'Custom Image URL'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCatalogSearchTab(),
                _buildCustomUrlTab(),
              ],
            ),
          ),

          // Action Buttons Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  /// Compact live preview rendering the selected art crop inside [CommanderArtBackdrop]
  /// with a simulated mock quadrant layout.
  Widget _buildLivePreviewBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedArtUrl != null ? AppColors.accentGold : Colors.white24,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Simulated Commander Art Backdrop
          Positioned.fill(
            child: CommanderArtBackdrop(
              imageUrl: _selectedArtUrl,
              opacity: 0.35,
            ),
          ),

          // Foreground simulated life display and player label
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.playerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                Flexible(
                  child: Text(
                    _selectedCardName ?? 'No Art Selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mock centered life number to confirm text legibility
          const Center(
            child: Text(
              '40',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 36,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 4,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PREVIEW',
                style: TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scryfall Catalog search tab
  Widget _buildCatalogSearchTab() {
    return Column(
      children: [
        // Search Input Field
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('art_search_input'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search Scryfall card by name (e.g. Atraxa, Urza)...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E222B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Results or Loading Indicator
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accentGold),
                )
              : _searchError != null
                  ? Center(
                      child: Text(
                        _searchError!,
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? const Center(
                          child: Text(
                            'Search Scryfall to browse card backdrops',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        )
                      : _buildCardResultsGrid(),
        ),
      ],
    );
  }

  Widget _buildCardResultsGrid() {
    return GridView.builder(
      key: const Key('art_results_grid'),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final card = _searchResults[index];
        final name = card['name'] as String? ?? 'Card';
        final setCode = (card['set'] as String? ?? '').toUpperCase();
        final hasFaces = card['card_faces'] is List &&
            (card['card_faces'] as List).length > 1;

        final artUrl = _extractArtCrop(card, 0);
        final isSelected = _selectedArtUrl == artUrl;

        return GestureDetector(
          key: Key('card_result_tile_$index'),
          onTap: () => _selectCard(card, 0),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF1C222C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.accentGold : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Art thumbnail
                if (artUrl != null)
                  CountrCachedImage(
                    imageUrl: artUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: Colors.black26),
                  ),

                // Gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.35, 1.0],
                    ),
                  ),
                ),

                // Card info
                Positioned(
                  bottom: 6,
                  left: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (setCode.isNotEmpty)
                        Text(
                          setCode,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),

                // DFC Face switcher
                if (hasFaces)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        final nextFace = _selectedFaceIndex == 0 ? 1 : 0;
                        _selectCard(card, nextFace);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white30, width: 0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flip_camera_android, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text('DFC', style: TextStyle(color: Colors.white, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Custom URL input tab
  Widget _buildCustomUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Direct Card Art or Image URL',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste any high-resolution Scryfall art_crop URL or custom image URL below:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('custom_url_input'),
            controller: _customUrlController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://cards.scryfall.io/art_crop/...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1E222B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check, color: AppColors.accentGold),
                onPressed: () {
                  final url = _customUrlController.text.trim();
                  if (url.isNotEmpty) {
                    setState(() {
                      _selectedArtUrl = url;
                      _selectedCardName = 'Custom Image';
                    });
                  }
                },
              ),
            ),
            onSubmitted: (url) {
              final trimmed = url.trim();
              if (trimmed.isNotEmpty) {
                setState(() {
                  _selectedArtUrl = trimmed;
                  _selectedCardName = 'Custom Image';
                });
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Tip: You can copy any direct image link from Scryfall or MTG art archives. It will be cached locally on your device for offline play.',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Bottom action bar: Reset to Default, Cancel, Apply Backdrop
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF101318),
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Reset to default commander art button
            TextButton.icon(
              key: const Key('reset_default_art_button'),
              onPressed: _resetToDefault,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white60),
              label: const Text(
                'Reset Default',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),

            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cancel
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 4),

                  // Apply Backdrop button
                  ElevatedButton.icon(
                    key: const Key('apply_art_override_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Apply Backdrop',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _selectedArtUrl != null ? _applyOverride : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

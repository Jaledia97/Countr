import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/conflict_resolution_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Modal bottom sheet allowing users to allocate card copies across multiple decks
/// with [-] {quantity} [+] steppers, inventory tracking, and TCG domain filters.
class MultiDeckAllocationSheet extends ConsumerStatefulWidget {
  final VaultItem item;

  const MultiDeckAllocationSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, VaultItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => MultiDeckAllocationSheet(item: item),
    );
  }

  @override
  ConsumerState<MultiDeckAllocationSheet> createState() =>
      _MultiDeckAllocationSheetState();
}

class _MultiDeckAllocationSheetState
    extends ConsumerState<MultiDeckAllocationSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newDeckController = TextEditingController();
  Timer? _debounceTimer;
  String _selectedDomain = 'all';
  String _searchQuery = '';
  bool _isCreatingDeck = false;

  static const _domainOptions = [
    {'id': 'all', 'label': 'All'},
    {'id': 'mtg', 'label': 'Magic: The Gathering'},
    {'id': 'pokemon', 'label': 'Pokémon'},
    {'id': 'lorcana', 'label': 'Disney Lorcana'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _newDeckController.dispose();
    super.dispose();
  }

  IconData _getDomainIcon(String? domain) {
    switch (domain?.toLowerCase()) {
      case 'mtg':
        return Icons.auto_awesome_rounded;
      case 'pokemon':
        return Icons.catching_pokemon;
      case 'lorcana':
        return Icons.star_rounded;
      default:
        return Icons.style_outlined;
    }
  }

  Future<void> _handleIncrement(Deck deck, int availableQty) async {
    final dao = ref.read(vaultDaoProvider);

    // If deck is physically registered and we have 0 available physical copies
    if (deck.isRegistered && availableQty <= 0) {
      final activeDecks =
          await dao.getDecksUsingItem(widget.item.id, onlyRegistered: true);

      if (mounted) {
        if (activeDecks.isNotEmpty) {
          await ConflictResolutionModal.show(
            context: context,
            cardName: widget.item.name,
            deckNames: activeDecks,
            onMovePhysical: () async {
              await dao.moveCardToDeck(widget.item.id, deck.id);
            },
            onAddAsProxy: () async {
              await dao.addCardToDeck(deck.id, widget.item.id, isProxy: true);
            },
          );
        } else {
          // No conflicting registered deck names, add directly as proxy
          await dao.addCardToDeck(deck.id, widget.item.id, isProxy: true);
        }
      }
    } else {
      // Draft deck or physical stock available: increment physical copy
      await dao.addCardToDeck(deck.id, widget.item.id, isProxy: false);
    }
  }

  Future<void> _handleDecrement(Deck deck) async {
    final dao = ref.read(vaultDaoProvider);
    await dao.removeCardFromDeck(deck.id, widget.item.id, quantity: 1);
  }

  Future<void> _handleCreateAndAddDeck() async {
    final name = _newDeckController.text.trim();
    if (name.isEmpty || _isCreatingDeck) return;

    setState(() => _isCreatingDeck = true);
    final dao = ref.read(vaultDaoProvider);

    try {
      final domain = _selectedDomain != 'all' ? _selectedDomain : 'mtg';
      final newDeck = await dao.createDeck(
        name,
        tcgDomain: domain,
        format: domain == 'mtg' ? 'Commander' : 'Standard',
      );

      await dao.addCardToDeck(newDeck.id, widget.item.id, isProxy: false);

      _newDeckController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "$name" and added 1 copy!'),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isCreatingDeck = false);
      }
    } catch (e, stackTrace) {
      debugPrint('[MultiDeckAllocationSheet._handleCreateNewDeck] Operation failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create deck: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isCreatingDeck = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(vaultDaoProvider);
    final decksAsync = ref.watch(deckListProvider);
    final allocationsAsync =
        ref.watch(cardDeckAllocationsProvider(widget.item.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.50,
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

              // Pinned Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      color: AppColors.accentVioletLight,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Card to Deck',
                            key: Key('multi_deck_sheet_title'),
                            style: AppTypography.heading2,
                          ),
                          Text(
                            'Add / Edit in Decks • ${widget.item.name}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('multi_deck_close_button'),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

              // Stream-based Content Body
              Expanded(
                child: StreamBuilder<int>(
                  stream: dao.watchAvailableQuantity(widget.item.id),
                  initialData: widget.item.quantity,
                  builder: (context, availSnapshot) {
                    final availableQty =
                        availSnapshot.data ?? widget.item.quantity;
                    final allocations =
                        allocationsAsync.asData?.value ?? <String, int>{};
                    final inDecks = allocations.values
                        .fold(0, (sum, val) => sum + val);

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildInventorySummary(availableQty, inDecks),
                        const SizedBox(height: 14),
                        _buildFilters(),
                        ...decksAsync.when(
                          data: (rawDecks) {
                            final decks = rawDecks.isEmpty
                                ? MockDeckData.defaultDecks
                                : rawDecks;
                            final filteredDecks = decks.where((d) {
                              if (_selectedDomain != 'all' &&
                                  d.tcgDomain.toLowerCase() !=
                                      _selectedDomain.toLowerCase()) {
                                return false;
                              }
                              if (_searchQuery.isNotEmpty &&
                                  !d.name.toLowerCase().contains(_searchQuery)) {
                                return false;
                              }
                              return true;
                            }).toList();

                            if (filteredDecks.isEmpty) {
                              return [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.search_off_rounded,
                                          size: 40,
                                          color: Colors.white24,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No decks matching "$_searchQuery"'
                                              : 'No decks found in this category',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ];
                            }

                            return [
                              for (final deck in filteredDecks)
                                _buildDeckRow(
                                  deck: deck,
                                  currentQty: allocations[deck.id] ?? 0,
                                  availableQty: availableQty,
                                ),
                            ];
                          },
                          loading: () => const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ],
                          error: (_, _) => const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'Failed to load decks.',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),

              // Inline New Deck Creation Footer
              const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newDeckController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Or enter new deck name...',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: AppColors.surfaceRaised,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.surfaceBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.surfaceBorderSubtle),
                            ),
                          ),
                          onSubmitted: (_) => _handleCreateAndAddDeck(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('button_create_and_add_deck'),
                        icon: _isCreatingDeck
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                              )
                            : const Icon(Icons.add_circle, color: AppColors.accentCyan, size: 28),
                        onPressed: _isCreatingDeck ? null : _handleCreateAndAddDeck,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventorySummary(int availableQty, int inDecks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryColumn('Total Owned', '${widget.item.quantity}', AppColors.accentCyan),
          Container(width: 1, height: 28, color: AppColors.surfaceBorderSubtle),
          _buildSummaryColumn('Available', '$availableQty', AppColors.accentEmerald),
          Container(width: 1, height: 28, color: AppColors.surfaceBorderSubtle),
          _buildSummaryColumn('In Decks', '$inDecks', AppColors.accentVioletLight),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search TextField
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search decks...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceRaised,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Domain Choice Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _domainOptions.map((opt) {
              final isSelected = _selectedDomain == opt['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceRaised,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDomain = opt['id']!);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDeckRow({
    required Deck deck,
    required int currentQty,
    required int availableQty,
  }) {
    final domainIcon = _getDomainIcon(deck.tcgDomain);

    return Container(
      key: Key('deck_allocation_row_${deck.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: currentQty > 0
            ? AppColors.accentCyan.withValues(alpha: 0.08)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentQty > 0
              ? AppColors.accentCyan.withValues(alpha: 0.4)
              : AppColors.surfaceBorderSubtle,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (currentQty == 0) {
            _handleIncrement(deck, availableQty);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Domain Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(domainIcon, size: 18, color: AppColors.accentCyan),
              ),
              const SizedBox(width: 12),

              // Title and Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            deck.format,
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: deck.isRegistered
                                ? AppColors.accentEmerald.withValues(alpha: 0.15)
                                : AppColors.textMuted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            deck.isRegistered ? '🔒 Registered' : '📝 Draft',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: deck.isRegistered
                                  ? AppColors.accentEmerald
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stepper [-] {quantity} [+]
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('stepper_decrement_${deck.id}'),
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    color: currentQty > 0
                        ? AppColors.accentAmber
                        : AppColors.textMuted.withValues(alpha: 0.3),
                    onPressed: currentQty > 0 ? () => _handleDecrement(deck) : null,
                  ),
                  Container(
                    key: Key('stepper_quantity_${deck.id}'),
                    constraints: const BoxConstraints(minWidth: 24),
                    alignment: Alignment.center,
                    child: Text(
                      '$currentQty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: currentQty > 0
                            ? AppColors.accentCyan
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('stepper_increment_${deck.id}'),
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    color: AppColors.accentCyan,
                    onPressed: () => _handleIncrement(deck, availableQty),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

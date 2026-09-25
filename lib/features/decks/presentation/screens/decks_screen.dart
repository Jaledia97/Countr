import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';

/// Decks Screen with top-level TCG context dropdown, list filtering, and FAB deck creation.
class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends ConsumerState<DecksScreen> {
  int _activeTab = 0;
  int _deckCount = 6;

  final List<Map<String, dynamic>> _mockDecks = [
    {
      'id': 'deck-edgar-markov',
      'title': 'Edgar Markov Aristocrats',
      'format': 'MTG Commander',
      'cardCount': '100/100',
      'colors': [Colors.white, Colors.black, Colors.red],
      'winRate': '68%',
      'tcgDomain': 'mtg',
      'isRegistered': true,
      'isCompetitive': false,
    },
    {
      'id': 'deck-charizard-ex',
      'title': 'Charizard ex / Pidgeot ex',
      'format': 'Pokémon Standard',
      'cardCount': '60/60',
      'colors': [Colors.orange, Colors.red],
      'winRate': '74%',
      'tcgDomain': 'pokemon',
      'isRegistered': true,
      'isCompetitive': true,
    },
    {
      'id': 'deck-yuriko',
      'title': 'Yuriko, the Tiger\'s Shadow',
      'format': 'MTG Commander (cEDH)',
      'cardCount': '100/100',
      'colors': [Colors.blue, Colors.black],
      'winRate': '82%',
      'tcgDomain': 'mtg',
      'isRegistered': false,
      'isCompetitive': true,
    },
    {
      'id': 'deck-lorcana',
      'title': 'Ruby / Amethyst Bounce Control',
      'format': 'Disney Lorcana Core',
      'cardCount': '60/60',
      'colors': [Colors.red, Colors.purple],
      'winRate': '70%',
      'tcgDomain': 'lorcana',
      'isRegistered': false,
      'isCompetitive': false,
    },
    {
      'id': 'deck-lost-zone',
      'title': 'Lost Zone Giratina VSTAR',
      'format': 'Pokémon Standard',
      'cardCount': '60/60',
      'colors': [Colors.purple, Colors.teal],
      'winRate': '65%',
      'tcgDomain': 'pokemon',
      'isRegistered': true,
      'isCompetitive': true,
    },
    {
      'id': 'deck-tron',
      'title': 'Modern Mono-Green Tron',
      'format': 'MTG Modern',
      'cardCount': '75/75',
      'colors': [Colors.green],
      'winRate': '55%',
      'tcgDomain': 'mtg',
      'isRegistered': false,
      'isCompetitive': false,
    },
  ];

  static const List<Map<String, dynamic>> _tcgOptions = [
    {
      'domain': 'all',
      'label': 'All Decks',
      'icon': Icons.all_inbox_rounded,
      'color': AppColors.accentCyan,
    },
    {
      'domain': 'mtg',
      'label': 'Magic: The Gathering',
      'icon': Icons.auto_awesome_rounded,
      'color': AppColors.accentViolet,
    },
    {
      'domain': 'pokemon',
      'label': 'Pokémon',
      'icon': Icons.catching_pokemon_rounded,
      'color': AppColors.accentAmber,
    },
    {
      'domain': 'lorcana',
      'label': 'Disney Lorcana',
      'icon': Icons.auto_stories_rounded,
      'color': AppColors.accentVioletLight,
    },
  ];

  String _getDropdownTitle(String activeFilter) {
    for (final option in _tcgOptions) {
      if (option['domain'] == activeFilter) {
        return option['label'] as String;
      }
    }
    return 'All Decks';
  }

  void _createNewDeck() {
    final activeFilter = ref.read(activeDeckTcgFilterProvider);
    final String domain;
    final String format;
    final String cardCount;
    final List<Color> colors;

    switch (activeFilter.toLowerCase()) {
      case 'pokemon':
        domain = 'pokemon';
        format = 'Pokémon Standard';
        cardCount = '0/60';
        colors = [Colors.orange, Colors.red];
        break;
      case 'lorcana':
        domain = 'lorcana';
        format = 'Disney Lorcana Core';
        cardCount = '0/60';
        colors = [Colors.red, Colors.purple];
        break;
      case 'mtg':
      case 'all':
      default:
        domain = 'mtg';
        format = 'MTG Commander';
        cardCount = '0/100';
        colors = [AppColors.accentCyan];
        break;
    }

    setState(() {
      _deckCount++;
      _mockDecks.insert(0, {
        'id': 'deck-${DateTime.now().millisecondsSinceEpoch}',
        'title': 'New $format Brew #$_deckCount',
        'format': format,
        'cardCount': cardCount,
        'colors': colors,
        'winRate': '--',
        'tcgDomain': domain,
        'isRegistered': false,
        'isCompetitive': false,
      });
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Deck created! Total decks: $_deckCount'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(activeDeckTcgFilterProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    // Filter by TCG domain first
    final domainDecks = _mockDecks.where((deck) {
      if (activeFilter == 'all') return true;
      return deck['tcgDomain'] == activeFilter;
    }).toList();

    // Filter by Subheader Tab next
    final filteredDecks = domainDecks.where((deck) {
      if (_activeTab == 1) {
        return deck['isCompetitive'] == true;
      } else if (_activeTab == 2) {
        return deck['isRegistered'] == false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Deck Builder',
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(width: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashColor:
                            AppColors.accentCyan.withValues(alpha: 0.12),
                        highlightColor:
                            AppColors.accentCyan.withValues(alpha: 0.06),
                      ),
                      child: PopupMenuButton<String>(
                        key: const Key('decks_tcg_context_switcher'),
                        tooltip: 'Select TCG Domain',
                        initialValue: activeFilter,
                        offset: const Offset(0, 46),
                        color: AppColors.surfaceRaised,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        onSelected: (String selected) {
                          ref.read(activeDeckTcgFilterProvider.notifier).state =
                              selected;
                        },
                        itemBuilder: (BuildContext context) {
                          return _tcgOptions.map((item) {
                            final domain = item['domain'] as String;
                            final label = item['label'] as String;
                            final icon = item['icon'] as IconData;
                            final color = item['color'] as Color;
                            final isSelected = activeFilter == domain;

                            return PopupMenuItem<String>(
                              key: Key('tcg_filter_$domain'),
                              value: domain,
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_rounded,
                                        color: color, size: 16),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getDropdownTitle(activeFilter),
                                style: AppTypography.heading1.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentCyan,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppColors.accentCyan,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('decks_privacy_mode_button'),
            icon: Icon(
              isPrivacyMode ? Icons.visibility_off : Icons.visibility,
              color: isPrivacyMode ? AppColors.accentAmber : AppColors.textSecondary,
            ),
            tooltip: isPrivacyMode ? 'Disable Privacy Mode' : 'Enable Privacy Mode',
            onPressed: () {
              ref.read(privacyModeProvider.notifier).state = !isPrivacyMode;
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Deck',
            onPressed: _createNewDeck,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('decks_new_deck_fab'),
        onPressed: _createNewDeck,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Deck'),
        backgroundColor: AppColors.accentCyan,
        foregroundColor: AppColors.textDark,
      ),
      body: Column(
        children: [
          // Subheader Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.surfaceBorderSubtle,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TabPill(
                    key: const Key('decks_tab_all'),
                    label: 'All Decks (${domainDecks.length})',
                    isSelected: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                  const SizedBox(width: 8),
                  _TabPill(
                    key: const Key('decks_tab_competitive'),
                    label: 'Competitive',
                    isSelected: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                  const SizedBox(width: 8),
                  _TabPill(
                    key: const Key('decks_tab_draft'),
                    label: 'Draft / In-Progress',
                    isSelected: _activeTab == 2,
                    onTap: () => setState(() => _activeTab = 2),
                  ),
                ],
              ),
            ),
          ),

          // Decks List or Empty State
          Expanded(
            child: filteredDecks.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.style_outlined,
                            size: 56,
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No decks found',
                            style: AppTypography.heading2.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "+ New Deck" to create one.',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDecks.length,
                    itemBuilder: (context, index) {
                      final deck = filteredDecks[index];
                      return InkWell(
                        key: Key('deck_item_${deck['id']}'),
                        onTap: () {
                          final deckId = deck['id'] as String? ??
                              DateTime.now().toIso8601String();
                          final dummyDeck = Deck(
                            id: deckId,
                            name: deck['title'] as String,
                            format: deck['format'] as String,
                            createdAt: DateTime.now(),
                            wins: 0,
                            losses: 0,
                            draws: 0,
                            tcgDomain: deck['tcgDomain'] as String? ?? 'mtg',
                            isRegistered: deck['isRegistered'] as bool? ?? false,
                            isCompetitive: deck['isCompetitive'] as bool? ?? false,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeckBuilderScreen(deck: dummyDeck),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.surfaceBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Card / Archetype Icon
                              Container(
                                width: 44,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.surfaceRaised,
                                      AppColors.surfaceHighlight,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: AppColors.accentViolet.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.style_rounded,
                                  color: AppColors.accentVioletLight,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Title & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deck['title'] as String,
                                      style: AppTypography.heading2.copyWith(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${deck['format']} • ${deck['cardCount']}',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),

                              // Win Rate Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.surfaceBorder,
                                  ),
                                ),
                                child: Text(
                                  deck['winRate'] as String,
                                  style: const TextStyle(
                                    color: AppColors.accentEmerald,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

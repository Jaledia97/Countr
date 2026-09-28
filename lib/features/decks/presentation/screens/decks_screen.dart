import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/skeleton_shimmer_box.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
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
      'colorIdentity': ['W', 'B', 'R'],
      'winRate': '68%',
      'tcgDomain': 'mtg',
      'isRegistered': true,
      'isCompetitive': false,
      'commanderName': 'Edgar Markov',
      'commanderImageUrl':
          'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-45c8-a90d-10b6394c3904.jpg',
      'commanderArtCrop':
          'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-45c8-a90d-10b6394c3904.jpg',
    },
    {
      'id': 'deck-charizard-ex',
      'title': 'Charizard ex / Pidgeot ex',
      'format': 'Pokémon Standard',
      'cardCount': '60/60',
      'colors': [Colors.orange, Colors.red],
      'colorIdentity': <String>[],
      'winRate': '74%',
      'tcgDomain': 'pokemon',
      'isRegistered': true,
      'isCompetitive': true,
      'commanderName': 'Charizard ex',
      'commanderImageUrl':
          'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
      'commanderArtCrop':
          'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'deck-yuriko',
      'title': 'Yuriko, the Tiger\'s Shadow',
      'format': 'MTG Commander (cEDH)',
      'cardCount': '100/100',
      'colors': [Colors.blue, Colors.black],
      'colorIdentity': ['U', 'B'],
      'winRate': '82%',
      'tcgDomain': 'mtg',
      'isRegistered': false,
      'isCompetitive': true,
      'commanderName': 'Yuriko, the Tiger\'s Shadow',
      'commanderImageUrl':
          'https://cards.scryfall.io/art_crop/front/3/6/364c9d94-60c7-41b4-bc1b-840a775693bd.jpg',
      'commanderArtCrop':
          'https://cards.scryfall.io/art_crop/front/3/6/364c9d94-60c7-41b4-bc1b-840a775693bd.jpg',
    },
    {
      'id': 'deck-lorcana',
      'title': 'Ruby / Amethyst Bounce Control',
      'format': 'Disney Lorcana Core',
      'cardCount': '60/60',
      'colors': [Colors.red, Colors.purple],
      'colorIdentity': <String>[],
      'winRate': '70%',
      'tcgDomain': 'lorcana',
      'isRegistered': false,
      'isCompetitive': false,
      'commanderName': 'Ruby / Amethyst Bounce Control',
      'commanderImageUrl':
          'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
      'commanderArtCrop':
          'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'deck-lost-zone',
      'title': 'Lost Zone Giratina VSTAR',
      'format': 'Pokémon Standard',
      'cardCount': '60/60',
      'colors': [Colors.purple, Colors.teal],
      'colorIdentity': <String>[],
      'winRate': '65%',
      'tcgDomain': 'pokemon',
      'isRegistered': true,
      'isCompetitive': true,
      'commanderName': 'Giratina VSTAR',
      'commanderImageUrl':
          'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
      'commanderArtCrop':
          'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'deck-tron',
      'title': 'Modern Mono-Green Tron',
      'format': 'MTG Modern',
      'cardCount': '75/75',
      'colors': [Colors.green],
      'colorIdentity': ['G'],
      'winRate': '55%',
      'tcgDomain': 'mtg',
      'isRegistered': false,
      'isCompetitive': false,
      'commanderName': 'Karn Liberated',
      'commanderImageUrl':
          'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
      'commanderArtCrop':
          'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
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
    final List<String> colorIdentity;

    switch (activeFilter.toLowerCase()) {
      case 'pokemon':
        domain = 'pokemon';
        format = 'Pokémon Standard';
        cardCount = '0/60';
        colors = [Colors.orange, Colors.red];
        colorIdentity = [];
        break;
      case 'lorcana':
        domain = 'lorcana';
        format = 'Disney Lorcana Core';
        cardCount = '0/60';
        colors = [Colors.red, Colors.purple];
        colorIdentity = [];
        break;
      case 'mtg':
      case 'all':
      default:
        domain = 'mtg';
        format = 'MTG Commander';
        cardCount = '0/100';
        colors = [AppColors.accentCyan];
        colorIdentity = ['W', 'B', 'R'];
        break;
    }

    final newId = 'deck-${DateTime.now().millisecondsSinceEpoch}';
    final newTitle = 'New $format Brew #$_deckCount';

    setState(() {
      _deckCount++;
      _mockDecks.insert(0, {
        'id': newId,
        'title': newTitle,
        'format': format,
        'cardCount': cardCount,
        'colors': colors,
        'colorIdentity': colorIdentity,
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

  Widget _buildCommanderCardArt(DeckSummary deck) {
    final artUrl = deck.commanderArtCrop ?? deck.commanderImageUrl;
    if (artUrl != null && artUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 56,
          color: AppColors.surfaceRaised,
          child: CountrCachedImage(
            imageUrl: artUrl,
            fit: BoxFit.cover,
            placeholder: const SkeletonShimmerBox(
              width: 44,
              height: 56,
              animate: false,
            ),
            errorWidget: _buildFallbackArt(deck),
          ),
        ),
      );
    }
    return _buildFallbackArt(deck);
  }

  Widget _buildFallbackArt(DeckSummary deck) {
    return Container(
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
    );
  }

  Widget _buildColorPips(DeckSummary deck) {
    if (deck.colorIdentity.isNotEmpty && deck.tcgDomain == 'mtg') {
      final manaCost = deck.colorIdentity.map((c) => '{$c}').join('');
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ManaCostBar(
          manaCost: manaCost,
          symbolSize: 12,
          spacing: 2,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAssemblyStatusPill(DeckSummary deck) {
    final Color badgeColor;
    final Color textColor;
    switch (deck.assemblyStatus) {
      case 'Assembled':
        badgeColor = AppColors.accentEmerald.withValues(alpha: 0.15);
        textColor = AppColors.accentEmerald;
        break;
      case 'Ready':
        badgeColor = AppColors.accentCyan.withValues(alpha: 0.15);
        textColor = AppColors.accentCyan;
        break;
      case 'Draft':
      default:
        badgeColor = AppColors.surfaceRaised;
        textColor = AppColors.accentAmber;
        break;
    }

    return Container(
      key: Key('deck_assembly_status_${deck.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        deck.assemblyStatus,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(activeDeckTcgFilterProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final dbSummaries = ref.watch(deckSummariesProvider).value;

    final List<DeckSummary> allSummaries;
    if (dbSummaries != null && dbSummaries.isNotEmpty) {
      allSummaries = dbSummaries;
    } else {
      allSummaries = _mockDecks.map((m) {
        final title = m['title'] as String? ?? 'Untitled Deck';
        final format = m['format'] as String? ?? 'MTG Commander';
        final domain = m['tcgDomain'] as String? ?? 'mtg';
        final isReg = m['isRegistered'] as bool? ?? false;
        final isComp = m['isCompetitive'] as bool? ?? false;
        final countStr = m['cardCount'] as String? ?? '0/100';
        final parts = countStr.split('/');
        final curCount = int.tryParse(parts.first) ?? 0;
        final targetCount =
            parts.length > 1 ? (int.tryParse(parts[1]) ?? 60) : 60;
        final colors = (m['colorIdentity'] as List?)?.cast<String>() ??
            (domain == 'mtg' ? ['W', 'B', 'R'] : <String>[]);

        return DeckSummary(
          id: m['id'] as String,
          name: title,
          format: format,
          tcgDomain: domain,
          isRegistered: isReg,
          isCompetitive: isComp,
          createdAt: DateTime.now(),
          cardCount: curCount,
          targetCardCount: targetCount,
          completeness: targetCount > 0 ? curCount / targetCount : 0.0,
          assemblyStatus: isReg
              ? 'Assembled'
              : (curCount >= targetCount && curCount > 0 ? 'Ready' : 'Draft'),
          colorIdentity: colors,
          commanderName: m['commanderName'] as String?,
          commanderImageUrl: m['commanderImageUrl'] as String?,
          commanderArtCrop: m['commanderArtCrop'] as String?,
          deck: Deck(
            id: m['id'] as String,
            name: title,
            format: format,
            tcgDomain: domain,
            isRegistered: isReg,
            isAssembled: isReg,
            isCompetitive: isComp,
            createdAt: DateTime.now(),
            wins: 0,
            losses: 0,
            draws: 0,
            isDeleted: false,
          ),
        );
      }).toList();
    }

    // Filter by TCG domain first
    final domainDecks = allSummaries.where((deck) {
      if (activeFilter == 'all') return true;
      return deck.tcgDomain == activeFilter;
    }).toList();

    // Filter by Subheader Tab next
    final filteredDecks = domainDecks.where((deck) {
      if (_activeTab == 1) {
        return deck.isCompetitive == true;
      } else if (_activeTab == 2) {
        return deck.isRegistered == false;
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
            key: const Key('deck_setup_wizard_button'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Deck',
            onPressed: () => DeckSetupWizardModal.show(
              context,
              initialTcgDomain: activeFilter,
            ),
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
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            key: const Key('decks_empty_wizard_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentCyan,
                              foregroundColor: AppColors.textDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('+ New Deck', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => DeckSetupWizardModal.show(
                              context,
                              initialTcgDomain: activeFilter,
                            ),
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
                      final cardCountDisplay =
                          '${deck.cardCount}/${deck.targetCardCount}';

                      return RepaintBoundary(
                        child: InkWell(
                          key: Key('deck_item_${deck.id}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeckBuilderScreen(deck: deck.deck),
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
                              // Commander Card Artwork / Archetype Icon with Skeleton Shimmer
                              _buildCommanderCardArt(deck),
                              const SizedBox(width: 14),

                              // Title, Format, Completeness & Inline Color Pips
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            deck.name,
                                            style: AppTypography.heading2.copyWith(fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: _buildAssemblyStatusPill(deck),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${deck.format} • $cardCountDisplay',
                                        style: AppTypography.caption,
                                      ),
                                    ),
                                    _buildColorPips(deck),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Completeness Percentage or Win Rate Pill
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
                                  deck.isRegistered
                                      ? '100%'
                                      : '${(deck.completeness * 100).toInt()}%',
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

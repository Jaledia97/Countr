import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Decks Screen.
/// Demonstrates local state freezing when switching between tabs.
class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  int _activeTab = 0;
  int _deckCount = 6;

  final List<Map<String, dynamic>> _mockDecks = [
    {
      'title': 'Edgar Markov Aristocrats',
      'format': 'MTG Commander',
      'cardCount': '100/100',
      'colors': [Colors.white, Colors.black, Colors.red],
      'winRate': '68%',
    },
    {
      'title': 'Charizard ex / Pidgeot ex',
      'format': 'Pokémon Standard',
      'cardCount': '60/60',
      'colors': [Colors.orange, Colors.red],
      'winRate': '74%',
    },
    {
      'title': 'Yuriko, the Tiger\'s Shadow',
      'format': 'MTG Commander (cEDH)',
      'cardCount': '100/100',
      'colors': [Colors.blue, Colors.black],
      'winRate': '82%',
    },
    {
      'title': 'Ruby / Amethyst Bounce Control',
      'format': 'Disney Lorcana Core',
      'cardCount': '60/60',
      'colors': [Colors.red, Colors.purple],
      'winRate': '70%',
    },
    {
      'title': 'Lost Zone Giratina VSTAR',
      'format': 'Pokémon Standard',
      'cardCount': '60/60',
      'colors': [Colors.purple, Colors.teal],
      'winRate': '65%',
    },
    {
      'title': 'Modern Mono-Green Tron',
      'format': 'MTG Modern',
      'cardCount': '75/75',
      'colors': [Colors.green],
      'winRate': '61%',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deck Builder', style: AppTypography.heading1),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Deck',
            onPressed: () {
              setState(() {
                _deckCount++;
                _mockDecks.insert(0, {
                  'title': 'New Custom Brew #$_deckCount',
                  'format': 'Custom Deck',
                  'cardCount': '0/60',
                  'colors': [AppColors.accentCyan],
                  'winRate': '--',
                });
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deck created! Total decks: $_deckCount'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subheader Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: AppColors.surfaceBorderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                _TabPill(
                  label: 'All Decks ($_deckCount)',
                  isSelected: _activeTab == 0,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  label: 'Competitive',
                  isSelected: _activeTab == 1,
                  onTap: () => setState(() => _activeTab = 1),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  label: 'Draft / In-Progress',
                  isSelected: _activeTab == 2,
                  onTap: () => setState(() => _activeTab = 2),
                ),
              ],
            ),
          ),

          // Decks List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mockDecks.length,
              itemBuilder: (context, index) {
                final deck = _mockDecks[index];
                return Container(
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
                            horizontal: 8, vertical: 4),
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

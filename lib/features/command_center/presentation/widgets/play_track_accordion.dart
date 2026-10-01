// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/state/app_state.dart';
import '../../../../features/decks/domain/models/deck_summary.dart';
import '../../../../features/life_counter/domain/models/pod_state.dart';
import '../../../../features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import '../../../../features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

/// Extension allowing convenient game context updating via StateController.
extension GameContextNotifierExtension on StateController<String> {
  void setGameContext(String tcg) {
    state = tcg;
  }
}

/// Accordion 2: "Play / Track +"
/// Overhauled in Countr 4.8 Patch (Requirement R4):
/// Eliminates nested child ExpansionTile expansion. Tapping a TCG card directly
/// sets the active TCG context (activeGameContextProvider) and opens PregameSetupSheet.
class PlayTrackAccordion extends StatelessWidget {
  final VoidCallback onModeSelected;
  final void Function(String format)? onLaunchMtgMode;
  final void Function(PodState podState)? onStartMatch;
  final List<DeckSummary>? injectedDecks;

  const PlayTrackAccordion({
    super.key,
    required this.onModeSelected,
    this.onLaunchMtgMode,
    this.onStartMatch,
    this.injectedDecks,
  });

  void _setActiveTcgContext(BuildContext context, String tcgName) {
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(activeGameContextProvider.notifier)
          .setGameContext(tcgName);
    } catch (_) {
      // Safe fallback if invoked in tests without an ancestor ProviderScope
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: AppColors.accentAmber,
              size: 20,
            ),
          ),
          title: const Text(
            'Play / Track +',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          childrenPadding: const EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12,
            top: 4,
          ),
          children: [
            // Direct Card 1: MTG
            _buildGameCard(
              context: context,
              key: const Key('play_track_card_mtg'),
              gameTitle: 'MTG',
              subtitle: 'Magic: The Gathering Formats',
              icon: Icons.shield_rounded,
              accentColor: AppColors.accentViolet,
              onTap: () => _handleCardTap(context, 'MTG'),
            ),

            const SizedBox(height: 6),

            // Direct Card 2: Pokémon
            _buildGameCard(
              context: context,
              key: const Key('play_track_card_pokemon'),
              gameTitle: 'Pokémon',
              subtitle: 'Pokémon TCG Formats',
              icon: Icons.catching_pokemon_rounded,
              accentColor: AppColors.accentAmber,
              onTap: () => _handleCardTap(context, 'Pokémon'),
            ),

            const SizedBox(height: 6),

            // Direct Card 3: Lorcana
            _buildGameCard(
              context: context,
              key: const Key('play_track_card_lorcana'),
              gameTitle: 'Lorcana',
              subtitle: 'Disney Lorcana Formats',
              icon: Icons.auto_awesome_rounded,
              accentColor: AppColors.accentCyan,
              onTap: () => _handleCardTap(context, 'Lorcana'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required Key key,
    required String gameTitle,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameTitle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCardTap(
    BuildContext context,
    String gameTitle,
  ) async {
    final tcgName = switch (gameTitle) {
      'MTG' => 'Magic: The Gathering',
      'Pokémon' => 'Pokémon',
      'Lorcana' => 'Disney Lorcana',
      _ => gameTitle,
    };

    // 1. Set the active TCG context in Riverpod
    _setActiveTcgContext(context, tcgName);

    // 2. Invoke mode selected hook
    onModeSelected();

    // 3. If explicit MTG launch hook provided, invoke it with Commander format
    if (gameTitle == 'MTG' && onLaunchMtgMode != null) {
      onLaunchMtgMode!('Commander');
      return;
    }

    // 4. Directly launch PregameSetupSheet
    final initialFormat = switch (gameTitle) {
      'MTG' => 'commander',
      'Pokémon' => 'standard',
      'Lorcana' => 'standard',
      _ => 'custom',
    };

    final podState = await PregameSetupSheet.show(
      context,
      initialTcg: tcgName,
      initialFormat: initialFormat,
      injectedDecks: injectedDecks,
      onStartMatch: onStartMatch,
    );

    if (podState != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PodScaffoldWidget(
            podState: podState,
            seatingOrientation: PregameSetupSheet.lastSeatingOrientation,
            isOledMode: PregameSetupSheet.lastOledMode,
            isImmersiveMode: PregameSetupSheet.lastImmersiveMode,
          ),
        ),
      );
    }
  }
}

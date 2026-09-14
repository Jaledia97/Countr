import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Accordion 2: "Play / Track +"
/// Features Nested ExpansionTiles:
/// - "MTG" -> Grandchildren: "Commander", "Standard", "Draft"
/// - "Pokémon" -> Grandchildren: "Standard", "GLC"
/// - "Lorcana" -> Grandchildren: "Core / Standard", "Draft"
class PlayTrackAccordion extends StatelessWidget {
  final VoidCallback onModeSelected;

  const PlayTrackAccordion({
    super.key,
    required this.onModeSelected,
  });

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
            // Nested ExpansionTile 1: MTG
            _buildNestedGameTile(
              context: context,
              gameTitle: 'MTG',
              subtitle: 'Magic: The Gathering Formats',
              icon: Icons.shield_rounded,
              accentColor: AppColors.accentViolet,
              modes: ['Commander', 'Standard', 'Draft'],
            ),

            const SizedBox(height: 6),

            // Nested ExpansionTile 2: Pokémon
            _buildNestedGameTile(
              context: context,
              gameTitle: 'Pokémon',
              subtitle: 'Pokémon TCG Formats',
              icon: Icons.catching_pokemon_rounded,
              accentColor: AppColors.accentAmber,
              modes: ['Standard', 'GLC'],
            ),

            const SizedBox(height: 6),

            // Nested ExpansionTile 3: Lorcana
            _buildNestedGameTile(
              context: context,
              gameTitle: 'Lorcana',
              subtitle: 'Disney Lorcana Formats',
              icon: Icons.auto_awesome_rounded,
              accentColor: AppColors.accentCyan,
              modes: ['Core / Standard', 'Draft'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNestedGameTile({
    required BuildContext context,
    required String gameTitle,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<String> modes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        leading: Icon(icon, color: accentColor, size: 20),
        title: Text(
          gameTitle,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.only(
          left: 20,
          right: 12,
          bottom: 10,
          top: 2,
        ),
        children: modes.map((mode) {
          return InkWell(
            onTap: () {
              onModeSelected();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Selected Play/Track mode: $gameTitle - $mode'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    mode,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

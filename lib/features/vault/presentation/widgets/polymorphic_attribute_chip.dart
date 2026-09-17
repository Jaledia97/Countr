import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Renders game-specific polymorphic dynamic attributes from the stringified
/// JSON payload based on collection_type.
class PolymorphicAttributeChip extends StatelessWidget {
  final String collectionType;
  final String dynamicDataJson;

  const PolymorphicAttributeChip({
    super.key,
    required this.collectionType,
    required this.dynamicDataJson,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(dynamicDataJson) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }

    // Switch statement based on collection_type to render polymorphic engine attributes
    switch (collectionType.toLowerCase()) {
      case 'mtg':
        final mana = data['mana'] ?? data['mana_cost'] ?? 'N/A';
        final type = data['type'] ?? data['type_line'] ?? 'Card';
        final power = data['power'];
        final toughness = data['toughness'];
        final ptString = (power != null && toughness != null) ? ' • $power/$toughness' : '';

        return _buildPill(
          icon: Icons.auto_awesome_rounded,
          accentColor: AppColors.accentViolet,
          label: 'MTG STATS',
          detail: '$mana • $type$ptString',
        );

      case 'pokemon':
        final hp = data['hp'] ?? 'N/A';
        final stage = data['stage'] ?? 'Standard';

        return _buildPill(
          icon: Icons.catching_pokemon_rounded,
          accentColor: AppColors.accentAmber,
          label: 'POKÉMON STATS',
          detail: 'HP $hp • Stage: $stage',
        );

      case 'comic':
        final issue = data['issue'] != null ? '#${data['issue']}' : '';
        final publisher = data['publisher'] ?? 'Comic';

        return _buildPill(
          icon: Icons.menu_book_rounded,
          accentColor: AppColors.accentEmerald,
          label: 'COMIC ISSUE',
          detail: '$publisher $issue',
        );

      case 'sports_card':
        final sport = data['sport'] ?? 'Sports';
        final team = data['team'] ?? '';
        final isRookie = data['is_rookie'] == true;

        return _buildPill(
          icon: Icons.sports_football_rounded,
          accentColor: AppColors.accentCyan,
          label: isRookie ? '★ ROOKIE CARD' : 'SPORTS CARD',
          detail: '$sport • $team',
          isHighlighted: isRookie,
        );

      default:
        return _buildPill(
          icon: Icons.data_object_rounded,
          accentColor: AppColors.textSecondary,
          label: 'METADATA',
          detail: data.isNotEmpty ? data.keys.first : 'Standard',
        );
    }
  }

  Widget _buildPill({
    required IconData icon,
    required Color accentColor,
    required String label,
    required String detail,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: isHighlighted ? 0.6 : 0.3),
          width: 0.8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: accentColor),
            const SizedBox(width: 5),
            Text(
              '$label: ',
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

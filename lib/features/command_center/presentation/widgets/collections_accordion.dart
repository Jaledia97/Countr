import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/state/app_state.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

/// Accordion 1: "Collections +"
/// Displays:
/// - "All Collections"
/// - "Magic: The Gathering"
/// - "Pokémon TCG"
/// - "Comic Books"
/// - "[ + Add Collection ]"
///
/// Tapping a game updates Riverpod state, closes the morphed menu,
/// and triggers a floating SnackBar.
class CollectionsAccordion extends ConsumerWidget {
  final VoidCallback onGameSelected;
  final ValueChanged<String>? onCollectionSelected;

  const CollectionsAccordion({
    super.key,
    required this.onGameSelected,
    this.onCollectionSelected,
  });

  static const List<Map<String, dynamic>> _collections = [
    {
      'title': 'All Collections',
      'key': 'all',
      'icon': Icons.all_inbox_rounded,
      'color': AppColors.accentCyan,
      'unitSingle': 'Item',
      'unitPlural': 'Items',
    },
    {
      'title': 'Magic: The Gathering',
      'key': 'mtg',
      'icon': Icons.auto_awesome_rounded,
      'color': AppColors.accentViolet,
      'unitSingle': 'Card',
      'unitPlural': 'Cards',
    },
    {
      'title': 'Pokémon TCG',
      'key': 'pokemon',
      'icon': Icons.catching_pokemon_rounded,
      'color': AppColors.accentAmber,
      'unitSingle': 'Card',
      'unitPlural': 'Cards',
    },
    {
      'title': 'Comic Books',
      'key': 'comic',
      'icon': Icons.menu_book_rounded,
      'color': AppColors.accentEmerald,
      'unitSingle': 'Issue',
      'unitPlural': 'Issues',
    },
    {
      'title': 'Sports Cards',
      'key': 'sports_card',
      'icon': Icons.sports_football_rounded,
      'color': AppColors.accentCyan,
      'unitSingle': 'Card',
      'unitPlural': 'Cards',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(activeGameContextProvider);
    final countsAsync = ref.watch(collectionItemCountsProvider);
    final counts = countsAsync.valueOrNull ?? const {};

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
              color: AppColors.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.collections_bookmark_rounded,
              color: AppColors.accentCyan,
              size: 20,
            ),
          ),
          title: const Text(
            'Collections +',
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
            // List of Collections
            ..._collections.map((item) {
              final title = item['title'] as String;
              final icon = item['icon'] as IconData;
              final color = item['color'] as Color;
              final key = item['key'] as String;
              final unitSingle = item['unitSingle'] as String;
              final unitPlural = item['unitPlural'] as String;
              final countVal = counts[key] ?? 0;
              final count = '$countVal ${countVal == 1 ? unitSingle : unitPlural}';
              final isSelected = activeGame == title;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : AppColors.surfaceBorderSubtle,
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Icon(icon, color: color, size: 20),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    count,
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: color, size: 18)
                      : const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.textMuted,
                          size: 13,
                        ),
                  onTap: () {
                    // 1. Update State Hook
                    ref.read(activeGameContextProvider.notifier).state = title;

                    // 2. Notify collection selected (e.g. route to Vault)
                    onCollectionSelected?.call(title);

                    // 3. Close Morphed Menu
                    onGameSelected();

                    // 4. Display SnackBar
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.surfaceRaised,
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: color, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Viewing $title in Vault',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            const SizedBox(height: 4),

            // Button: "[ + Add Collection ]"
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  foregroundColor: AppColors.accentCyan,
                  side: BorderSide(
                    color: AppColors.accentCyan.withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  '[ + Add Collection ]',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                onPressed: () {
                  onGameSelected();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening Add Collection Wizard...'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

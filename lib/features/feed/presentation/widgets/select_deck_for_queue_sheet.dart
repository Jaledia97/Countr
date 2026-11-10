// Copyright (c) 2026 Countr. All rights reserved.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../decks/domain/models/deck_summary.dart';
import '../../../decks/presentation/providers/deck_providers.dart';

/// Modal bottom sheet allowing a player to choose their deck when reserving
/// a spot in the next group game waitlist queue.
class SelectDeckForQueueSheet extends ConsumerStatefulWidget {
  const SelectDeckForQueueSheet({super.key});

  static Future<DeckSummary?> show(BuildContext context) {
    return showModalBottomSheet<DeckSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SelectDeckForQueueSheet(),
    );
  }

  @override
  ConsumerState<SelectDeckForQueueSheet> createState() =>
      _SelectDeckForQueueSheetState();
}

class _SelectDeckForQueueSheetState
    extends ConsumerState<SelectDeckForQueueSheet> {
  DeckSummary? _selectedDeck;

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(deckSummariesProvider);

    return Container(
      key: const Key('reserve_spot_deck_sheet'),
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Deck for Pod',
                          style: AppTypography.heading2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pre-loads commander and starting life when seated',
                          style: AppTypography.bodySecondary.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 1),

            // Decks list
            Expanded(
              child: decksAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading decks: $e',
                      style: const TextStyle(color: AppColors.accentRose)),
                ),
                data: (decks) {
                  if (decks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.style_outlined,
                              size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No saved decks found',
                            style: AppTypography.heading2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You will be seated with a default 40-life player.',
                            style: AppTypography.bodySecondary.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: decks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final deck = decks[index];
                      final isSelected = _selectedDeck?.id == deck.id;

                      return InkWell(
                        key: Key('queue_deck_option_${deck.id}'),
                        onTap: () {
                          setState(() {
                            _selectedDeck = deck;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentCyan.withValues(alpha: 0.12)
                                : AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentCyan
                                  : AppColors.surfaceBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Art crop or icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: deck.commanderArtCrop != null &&
                                        deck.commanderArtCrop!.isNotEmpty
                                    ? Image.network(
                                        deck.commanderArtCrop!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                    Icons.shield_outlined,
                                                    color:
                                                        AppColors.accentCyan),
                                      )
                                    : const Icon(Icons.style_rounded,
                                        color: AppColors.accentCyan),
                              ),
                              const SizedBox(width: 12),
                              // Deck details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deck.name,
                                      style: AppTypography.heading2.copyWith(
                                        fontSize: 15,
                                        color: isSelected
                                            ? AppColors.accentCyan
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (deck.commanderName != null)
                                      Text(
                                        deck.commanderName!,
                                        style:
                                            AppTypography.bodySecondary.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Radio indicator
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected
                                    ? AppColors.accentCyan
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('confirm_join_queue_btn'),
                  onPressed: () {
                    Navigator.of(context).pop(_selectedDeck);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Reservation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
}

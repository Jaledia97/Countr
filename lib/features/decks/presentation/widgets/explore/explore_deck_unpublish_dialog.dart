import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

/// Checks if the current user is the author of the explore deck.
bool isExploreDeckAuthor({
  required ExploreDeck deck,
  required String currentUserId,
}) {
  if (deck.authorId == currentUserId) return true;
  if (deck.authorId == '@$currentUserId') return true;

  const localAliases = {'local_user', 'user-current-me', 'me', 'currentuser', 'currentme'};
  final cleanUserId = currentUserId
      .replaceAll('user-', '')
      .replaceAll('store-', '')
      .replaceAll('_', '')
      .replaceAll('-', '')
      .toLowerCase();

  final cleanAuthorId = (deck.authorId ?? '')
      .replaceAll('@', '')
      .replaceAll('user-', '')
      .replaceAll('store-', '')
      .replaceAll('_', '')
      .replaceAll('-', '')
      .toLowerCase();

  if (deck.authorId != null && deck.authorId!.isNotEmpty) {
    if (cleanAuthorId == cleanUserId) return true;
    if (localAliases.contains(deck.authorId) &&
        (localAliases.contains(currentUserId) || localAliases.contains(cleanUserId))) {
      return true;
    }
  }

  final cleanCreator = deck.creatorName
      .replaceAll('@', '')
      .replaceAll('_', '')
      .replaceAll('-', '')
      .toLowerCase();

  if (cleanCreator.isNotEmpty && cleanCreator == cleanUserId) {
    return true;
  }

  if (localAliases.contains(cleanCreator) &&
      (localAliases.contains(currentUserId) || localAliases.contains(cleanUserId))) {
    return true;
  }

  return false;
}

/// Displays the mandatory confirmation dialog and executes the unpublish workflow.
Future<bool> showExploreDeckUnpublishWorkflow({
  required BuildContext context,
  required WidgetRef ref,
  required ExploreDeck deck,
  bool popOnSuccess = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.public_off_rounded, color: AppColors.accentRose, size: 22),
          SizedBox(width: 8),
          Text(
            'Unpublish Deck?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: const Text(
        'Unpublish from Explore? This removes the deck from public Explore. Your personal copy in My Decks will remain intact.',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel_unpublish_button'),
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          key: const Key('confirm_unpublish_button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentRose,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text(
            'Unpublish',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      final dao = ref.read(exploreDeckDaoProvider);

      await dao.unpublishExploreDeck(exploreDeckId: deck.id);

      // Invalidate relevant providers for immediate UI synchronization
      ref.invalidate(exploreDecksStreamProvider);
      ref.invalidate(exploreFilteredDeckCountProvider);
      ref.invalidate(featuredExploreCategoryStreamProvider);
      ref.invalidate(featuredCategoryDecksStreamProvider);
      ref.invalidate(featuredCategoryDeckCountProvider);
      ref.invalidate(userSharedDecksProvider(currentUserId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deck "${deck.name}" unpublished from Explore'),
            backgroundColor: AppColors.surfaceHighlight,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (popOnSuccess) {
          Navigator.of(context).pop();
        }
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unpublish deck: $e'),
            backgroundColor: AppColors.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
  return false;
}

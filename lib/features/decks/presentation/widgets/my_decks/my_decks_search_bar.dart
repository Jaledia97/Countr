import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';

/// Dedicated search bar for the "My Decks" tab with immediate query synchronization,
/// clear button, and dark surface styling.
class MyDecksSearchBar extends ConsumerStatefulWidget {
  const MyDecksSearchBar({super.key});

  @override
  ConsumerState<MyDecksSearchBar> createState() => _MyDecksSearchBarState();
}

class _MyDecksSearchBarState extends ConsumerState<MyDecksSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(myDecksSearchQueryProvider);
    _controller = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep local controller in sync if provider updates externally
    ref.listen<String>(myDecksSearchQueryProvider, (prev, next) {
      if (next != _controller.text) {
        _controller.text = next;
      }
    });

    final currentQuery = ref.watch(myDecksSearchQueryProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: TextField(
        key: const Key('my_decks_search_input'),
        controller: _controller,
        onChanged: (value) {
          ref.read(myDecksSearchQueryProvider.notifier).state = value;
        },
        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search my decks or cards...',
          hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          suffixIcon: currentQuery.isNotEmpty
              ? IconButton(
                  key: const Key('my_decks_search_clear_button'),
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    ref.read(myDecksSearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

export 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

/// Standalone screen hosting the set collections view [VaultCollectionViewSliver].
/// Allows navigating to set collections as a distinct routed view.
class CollectionsScreen extends ConsumerStatefulWidget {
  final String? initialGame;

  const CollectionsScreen({
    super.key,
    this.initialGame,
  });

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String activeGame = widget.initialGame ?? ref.watch(activeGameContextProvider);

    return Scaffold(
      key: const Key('collections_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Set Collections',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, color: AppColors.accentCyan, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search set collections...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          VaultCollectionViewSliver(
            activeGame: activeGame,
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          ),
        ],
      ),
    );
  }
}

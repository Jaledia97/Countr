import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/edit_binder_modal.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

/// Screen displaying the physical inventory of cards anchored to a specific Vault Binder.
/// Per the Anchor + Allocation architecture, this physical home anchor never forgets its cards.
class BinderDetailScreen extends ConsumerWidget {
  final VaultBinder binder;

  const BinderDetailScreen({
    super.key,
    required this.binder,
  });

  static Future<void> show(BuildContext context, VaultBinder binder) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BinderDetailScreen(binder: binder),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(vaultDaoProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final viewMode = ref.watch(binderViewModeProvider);
    final metadata = ref.watch(binderMetadataProvider(binder.id));

    // Watch binders to get reactive updates when edited
    final bindersAsync = ref.watch(bindersStreamProvider);
    final currentBinder = bindersAsync.maybeWhen(
      data: (binders) => binders.firstWhere((b) => b.id == binder.id, orElse: () => binder),
      orElse: () => binder,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentBinder.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              '${currentBinder.collectionType.toUpperCase()} Physical Anchor',
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          // Edit Binder button
          IconButton(
            key: const Key('binder_edit_button'),
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
            tooltip: 'Edit Binder',
            onPressed: () => EditBinderModal.show(context, currentBinder),
          ),
          // View Mode toggle (3x3 Grid vs List)
          IconButton(
            key: const Key('binder_view_mode_toggle'),
            icon: Icon(
              viewMode == BinderViewMode.grid3x3
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              color: AppColors.accentCyan,
              size: 22,
            ),
            tooltip: viewMode == BinderViewMode.grid3x3
                ? 'Switch to List View'
                : 'Switch to 3x3 Grid',
            onPressed: () {
              ref.read(binderViewModeProvider.notifier).state =
                  viewMode == BinderViewMode.grid3x3
                      ? BinderViewMode.list
                      : BinderViewMode.grid3x3;
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<VaultItem>>(
        stream: dao.watchItemsByBinder(currentBinder.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading binder: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: const Icon(Icons.folder_open_rounded,
                          color: AppColors.textMuted, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Binder is Empty',
                      style:
                          AppTypography.heading2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No cards are currently anchored to "${currentBinder.name}".\nTransfer scanned cards from your Inbox to place them in this physical home.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          // Calculate binder metrics
          final totalCards =
              items.fold<int>(0, (sum, item) => sum + item.quantity);
          final totalMarketValue = items.fold<double>(
              0.0, (sum, item) => sum + (item.currentMarketPrice * item.quantity));

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Summary Card
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F2633), Color(0xFF141923)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL BINDER VALUE',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      isPrivacyMode ? '****' : '\$${totalMarketValue.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.style_outlined,
                                        color: AppColors.accentEmerald, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$totalCards ${totalCards == 1 ? "Card" : "Cards"}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (metadata.description != null && metadata.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceRaised.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 14, color: AppColors.accentCyan),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    metadata.description!,
                                    key: const Key('binder_detail_description'),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Virtualized Cards View: 3x3 Grid or List
              if (viewMode == BinderViewMode.grid3x3)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 5 / 7,
                      crossAxisSpacing: 2.0,
                      mainAxisSpacing: 2.0,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return RepaintBoundary(
                        child: BinderGridCardTile(
                          item: item,
                          onTap: () => CardDetailSheet.show(
                            context,
                            item,
                            items: items,
                            initialIndex: index,
                            binderId: currentBinder.id,
                            binder: currentBinder,
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return RepaintBoundary(
                        child: VaultItemCard(
                          item: items[index],
                          initiallyExpanded: false,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 3x3 Grid Card Tile rendering in strict 5:7 card aspect ratio.
class BinderGridCardTile extends StatelessWidget {
  final VaultItem item;
  final VoidCallback onTap;

  const BinderGridCardTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  bool _isCardFoil(VaultItem item) {
    if (item.dynamicData.isNotEmpty) {
      final data = ParsedJsonCache.parse(item.dynamicData);
      final finish = data['finish']?.toString().toLowerCase();
      if (finish != null && (finish.contains('foil') || finish == 'etched')) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = item.imageUrl;
    final isFoil = _isCardFoil(item);

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 5 / 7,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFoil ? AppColors.accentGold.withValues(alpha: 0.6) : AppColors.surfaceBorder,
              width: isFoil ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Card Image
              CountrCachedImage(
                imageUrl: imgUrl,
                cardId: item.id,
                cardName: item.name,
                tcgDomain: item.collectionType,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Foil sheen overlay if foil
              if (isFoil)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withValues(alpha: 0.15),
                          Colors.amber.withValues(alpha: 0.15),
                          Colors.cyan.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

              // Quantity Badge (if > 1)
              if (item.quantity > 1)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accentCyan, width: 0.8),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

              // Foil star badge in bottom-left
              if (isFoil)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.accentGold,
                      size: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


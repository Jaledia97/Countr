import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
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
              binder.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              '${binder.collectionType.toUpperCase()} Physical Anchor',
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<VaultItem>>(
        stream: dao.watchItemsByBinder(binder.id),
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
                      'No cards are currently anchored to "${binder.name}".\nTransfer scanned cards from your Inbox to place them in this physical home.',
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
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
                            Text(
                              '\$${totalMarketValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Container(
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
                      ],
                    ),
                  ),
                ),
              ),

              // Virtualized Card List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return VaultItemCard(item: items[index]);
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

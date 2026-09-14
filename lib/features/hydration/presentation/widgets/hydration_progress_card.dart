import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';

/// Highly polished neon-themed progress card displayed during background
/// MTG catalog bulk ingestion.
class HydrationProgressCard extends ConsumerWidget {
  const HydrationProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hydrationControllerProvider);

    if (state.status == HydrationStatus.idle) {
      return const SizedBox.shrink();
    }

    final isComplete = state.isComplete;
    final isError = state.isError;

    final Color accentColor;
    final IconData statusIcon;
    final String badgeLabel;

    switch (state.status) {
      case HydrationStatus.fetchingMetadata:
        accentColor = AppColors.accentCyan;
        statusIcon = Icons.cloud_sync_rounded;
        badgeLabel = 'CONNECTING';
        break;
      case HydrationStatus.downloading:
        accentColor = AppColors.accentCyan;
        statusIcon = Icons.cloud_download_rounded;
        badgeLabel = 'DOWNLOADING';
        break;
      case HydrationStatus.parsingAndInserting:
        accentColor = AppColors.accentViolet;
        statusIcon = Icons.memory_rounded;
        badgeLabel = 'ISOLATE HYDRATING';
        break;
      case HydrationStatus.complete:
        accentColor = AppColors.accentEmerald;
        statusIcon = Icons.check_circle_rounded;
        badgeLabel = 'READY';
        break;
      case HydrationStatus.error:
        accentColor = AppColors.accentRose;
        statusIcon = Icons.error_outline_rounded;
        badgeLabel = 'FAILED';
        break;
      case HydrationStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusIcon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'HYDRATION ENGINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isComplete || isError)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: () =>
                      ref.read(hydrationControllerProvider.notifier).reset(),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: state.progress != null
                  ? LinearProgressIndicator(
                      value: state.progress,
                      backgroundColor: AppColors.surfaceBorderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    )
                  : LinearProgressIndicator(
                      backgroundColor: AppColors.surfaceBorderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // Footer Metrics / Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (state.status == HydrationStatus.downloading)
                Text(
                  state.downloadProgressText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                )
              else if (state.status == HydrationStatus.parsingAndInserting)
                Text(
                  '${state.insertedCount} cards ingested in 1,000-row chunks',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                )
              else if (isComplete)
                Text(
                  '${state.insertedCount} cards cached locally in Drift SQLite',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentEmerald,
                  ),
                )
              else if (isError)
                Text(
                  'Tap retry to resume ingestion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentRose.withValues(alpha: 0.8),
                  ),
                )
              else
                const SizedBox.shrink(),

              if (state.progress != null && state.isLoading)
                Text(
                  '${(state.progress! * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),

              if (isError)
                InkWell(
                  onTap: () => ref
                      .read(hydrationControllerProvider.notifier)
                      .startHydration(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.accentRose.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentRose,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/state/app_state.dart';
import 'app_settings_dialog.dart';
import 'collections_accordion.dart';
import 'play_track_accordion.dart';

export 'app_settings_dialog.dart';
import '../../../../features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import '../../../../features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import '../../../../features/hydration/presentation/controllers/hydration_state.dart';
import '../../../../features/hydration/presentation/providers/hydration_providers.dart';
import '../../../../features/vault/presentation/providers/vault_providers.dart';

/// The Morphing Global Command Center.
/// Morphs and expands directly outward from the Menu button (Alignment.bottomRight).
/// Does NOT route to a new screen or use a standard edge-sliding drawer.
class MorphingCommandCenter extends ConsumerStatefulWidget {
  const MorphingCommandCenter({super.key});

  /// Opens the morphing command center modal directly from the Menu button origin.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Command Center',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const MorphingCommandCenter();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Curve for organic expanding morph outward from bottom-right
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        // Scale outward anchored precisely at bottom-right (Menu button coordinate)
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * curvedAnimation.value,
            sigmaY: 6 * curvedAnimation.value,
          ),
          child: ScaleTransition(
            alignment: Alignment.bottomRight,
            scale: Tween<double>(
              begin: 0.15,
              end: 1.0,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<MorphingCommandCenter> createState() =>
      _MorphingCommandCenterState();
}

class _MorphingCommandCenterState extends ConsumerState<MorphingCommandCenter> {
  late final ScrollController _scrollController;
  bool _isSettingsDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGame = ref.watch(activeGameContextProvider);
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Center(
        child: Container(
          width: size.width > 600 ? 520 : size.width * 0.94,
          height: size.height * 0.86,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withValues(alpha: 0.18),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: AppColors.surface,
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 16,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: AppColors.accentCyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'COMMAND CENTER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Active Context: $activeGame',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.accentCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Close Menu',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // Active Context Status Indicator
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentViolet.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 18,
                          color: AppColors.accentVioletLight,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GLOBAL SCOPE CONTEXT',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                activeGame,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accentVioletLight,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Accordion 1: Collections +
                  CollectionsAccordion(
                    onCollectionSelected: (collection) {
                      context.go('/vault');
                    },
                    onGameSelected: () {
                      Navigator.of(context).pop();
                    },
                  ),

                  const SizedBox(height: 8),

                  // Accordion 2: Play / Track +
                  PlayTrackAccordion(
                    onModeSelected: () {
                      Navigator.of(context).pop();
                    },
                    onLaunchMtgMode: (mode) async {
                      // 1. Open pregame setup on root navigator context (modal already dismissed by onModeSelected)
                      final rootContext =
                          rootNavigatorKey.currentContext ?? context;
                      final podState = await PregameSetupSheet.show(
                        rootContext,
                        initialFormat: mode.toLowerCase(),
                      );

                      // 3. When setup completes and returns podState, push PodScaffoldWidget
                      if (podState != null) {
                        final navContext =
                            rootNavigatorKey.currentContext ?? rootContext;
                        if (navContext.mounted) {
                          Navigator.of(navContext).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PodScaffoldWidget(podState: podState),
                            ),
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 8),

                  // Test & Developer Tools Section Card
                  Container(
                    key: const Key('command_center_developer_tools_card'),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              size: 16,
                              color: AppColors.accentCyan,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'TEST & DEVELOPER TOOLS',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEV',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentCyan,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 1. Hydration Engine Action Trigger
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.surfaceBorderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                size: 20,
                                color: AppColors.accentCyan,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Hydration Engine',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ref
                                                  .watch(
                                                    hydrationControllerProvider,
                                                  )
                                                  .status ==
                                              HydrationStatus.idle
                                          ? 'Hydrate MTG Dictionary from Scryfall'
                                          : 'Status: ${ref.watch(hydrationControllerProvider).status.name}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                key: const Key('command_center_hydrate_button'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentCyan,
                                  foregroundColor: AppColors.textDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () {
                                  ref
                                      .read(
                                        hydrationControllerProvider.notifier,
                                      )
                                      .startHydration();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        'Starting MTG bulk hydration...',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Hydrate',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 2. Database Verification Action Trigger
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.surfaceBorderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sync_rounded,
                                size: 20,
                                color: AppColors.accentEmerald,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Database Verification',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Verify SQLite schema and reseed catalog',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                key: const Key(
                                  'command_center_verify_database_button',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentEmerald,
                                  foregroundColor: AppColors.textDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(vaultDaoProvider)
                                      .seedDatabase();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Database verified and seeded.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Utilities Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: _QuickActionItem(
                              icon: Icons.price_check_rounded,
                              label: 'TCG Pricing',
                              onTap: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Offline TCG Pricing active'),
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: _QuickActionItem(
                              icon: Icons.sync_rounded,
                              label: 'Sync Status',
                              onTap: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Local-first storage in sync',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: _QuickActionItem(
                              key: const Key(
                                'command_center_settings_quick_action',
                              ),
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () async {
                                if (_isSettingsDialogOpen) return;
                                _isSettingsDialogOpen = true;
                                try {
                                  await AppSettingsDialog.show(context);
                                } finally {
                                  if (mounted) {
                                    _isSettingsDialogOpen = false;
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

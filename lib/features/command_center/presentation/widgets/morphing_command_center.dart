import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/state/app_state.dart';
import 'collections_accordion.dart';
import 'play_track_accordion.dart';

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
            scale: Tween<double>(begin: 0.15, end: 1.0).animate(curvedAnimation),
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
  @override
  Widget build(BuildContext context) {
    final activeGame = ref.watch(activeGameContextProvider);
    final userPersona = ref.watch(userPersonaProvider);
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
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textPrimary),
                    tooltip: 'Close Menu',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // Active Context Status Indicator
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet.withValues(alpha: 0.2),
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

                  // Global Persona Switcher Toggle
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.switch_account_rounded,
                                  size: 16,
                                  color: AppColors.accentCyan,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'VIEWING PERSONA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                userPersona == UserPersona.investor
                                    ? 'INVESTOR MODE'
                                    : 'PLAYER MODE',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: userPersona == UserPersona.investor
                                      ? AppColors.accentEmerald
                                      : AppColors.accentVioletLight,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceBorderSubtle),
                          ),
                          child: Row(
                            children: [
                              // Investor Segment
                              Expanded(
                                child: GestureDetector(
                                  key: const Key('persona_toggle_investor'),
                                  onTap: () {
                                    ref.read(userPersonaProvider.notifier).state =
                                        UserPersona.investor;
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    decoration: BoxDecoration(
                                      color: userPersona == UserPersona.investor
                                          ? AppColors.accentEmerald
                                              .withValues(alpha: 0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      border: userPersona == UserPersona.investor
                                          ? Border.all(
                                              color: AppColors.accentEmerald
                                                  .withValues(alpha: 0.6),
                                              width: 1.2,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('💼',
                                              style: TextStyle(fontSize: 13)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Investor',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: userPersona ==
                                                      UserPersona.investor
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: userPersona ==
                                                      UserPersona.investor
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Player Segment
                              Expanded(
                                child: GestureDetector(
                                  key: const Key('persona_toggle_player'),
                                  onTap: () {
                                    ref.read(userPersonaProvider.notifier).state =
                                        UserPersona.player;
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    decoration: BoxDecoration(
                                      color: userPersona == UserPersona.player
                                          ? AppColors.accentViolet
                                              .withValues(alpha: 0.25)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      border: userPersona == UserPersona.player
                                          ? Border.all(
                                              color: AppColors.accentViolet
                                                  .withValues(alpha: 0.7),
                                              width: 1.2,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('⚔️',
                                              style: TextStyle(fontSize: 13)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Player',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: userPersona ==
                                                      UserPersona.player
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: userPersona ==
                                                      UserPersona.player
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                          _QuickActionItem(
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
                          _QuickActionItem(
                            icon: Icons.sync_rounded,
                            label: 'Sync Status',
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Local-first storage in sync'),
                                ),
                              );
                            },
                          ),
                          _QuickActionItem(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Opening Countr Settings...'),
                                ),
                              );
                            },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

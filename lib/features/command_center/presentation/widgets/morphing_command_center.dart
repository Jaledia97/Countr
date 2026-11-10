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
import '../../../../features/auth/presentation/widgets/verified_store_badge.dart';
import '../../../../features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import '../../../../features/profile/presentation/providers/profile_providers.dart';
import '../../../../features/feed/presentation/providers/feed_providers.dart';
import '../../../../features/feed/presentation/screens/saved_posts_screen.dart';

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
                  // Top-Most Active Profile Tile
                  _MyProfileCommandCenterTile(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/profile/me');
                    },
                  ),
                  const SizedBox(height: 6),

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
                                'command_center_friends_quick_action',
                              ),
                              icon: Icons.people_outline_rounded,
                              label: 'Friends & Groups',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/friends');
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

                  const SizedBox(height: 12),

                  // High-visibility Log Out button at bottom of Command Center
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('command_center_logout_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceRaised,
                          foregroundColor: AppColors.accentRed,
                          side: BorderSide(
                            color: AppColors.accentRed.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () {
                          LogoutConfirmationDialog.show(context);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
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

class _MyProfileCommandCenterTile extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const _MyProfileCommandCenterTile({required this.onTap});

  @override
  ConsumerState<_MyProfileCommandCenterTile> createState() =>
      _MyProfileCommandCenterTileState();
}

class _MyProfileCommandCenterTileState
    extends ConsumerState<_MyProfileCommandCenterTile> {
  bool _isSavedPostsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    final userTier = ref.watch(currentUserTierProvider);
    final savedCountAsync = ref.watch(savedPostsCountProvider);
    final savedCount = savedCountAsync.valueOrNull ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Profile Tile Row (Tapping navigates to /profile/me)
          InkWell(
            key: const Key('command_center_my_profile_tile'),
            onTap: widget.onTap,
            borderRadius: _isSavedPostsExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Circular Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceHighlight,
                    backgroundImage: profile?.avatarUrl != null &&
                            profile!.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: (profile?.avatarUrl == null ||
                            profile!.avatarUrl!.isEmpty)
                        ? Text(
                            (profile?.displayName.isNotEmpty == true)
                                ? profile!.displayName.substring(0, 1).toUpperCase()
                                : 'G',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Middle Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile?.displayName ?? 'Guest Collector',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (profile?.isVerifiedBusiness == true) ...[
                              const SizedBox(width: 6),
                              const VerifiedStoreBadge(iconSize: 11, fontSize: 8.5),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              profile?.username ?? '@guest',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accentCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Tier pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.accentViolet.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                userTier.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentVioletLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Trailing Chevron Button expanding downward
                  IconButton(
                    key: const Key('command_center_profile_chevron'),
                    icon: Icon(
                      _isSavedPostsExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.expand_more,
                      color: AppColors.accentCyan,
                      size: 24,
                    ),
                    tooltip: _isSavedPostsExpanded ? 'Collapse' : 'Expand Saved Posts',
                    onPressed: () {
                      setState(() {
                        _isSavedPostsExpanded = !_isSavedPostsExpanded;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 2. Expandable Saved Posts Row (Key('command_center_saved_posts_tile'))
          if (_isSavedPostsExpanded) ...[
            const Divider(color: AppColors.surfaceBorderSubtle, height: 1),
            InkWell(
              key: const Key('command_center_saved_posts_tile'),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: () {
                Navigator.of(context).pop();
                try {
                  context.push('/saved-posts');
                } catch (_) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        color: AppColors.accentAmber,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Posts',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'View bookmarked feed posts',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Count Badge
                    Container(
                      key: const Key('command_center_saved_posts_count_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accentAmber.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$savedCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/core/state/tcg_context_sync.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import '../widgets/custom_bottom_nav_bar.dart';

/// The Main Shell Screen wrapping the StatefulNavigationShell.
/// Hosts the persistent navigation shell and the 5-item custom bottom nav bar.
/// Observes AppLifecycleState to enforce Streamer Security (auto-enabling Privacy Mode when backgrounded).
class MainShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleChange,
    );
    // Warm up the database and initial vault items in the background
    // so navigating to Vault is instantaneous with zero load lag
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(vaultDaoProvider);
        ref.read(vaultItemsStreamProvider);
        ref.read(mtgAutoHydrationCoordinatorProvider).checkAndTriggerAutoHydration();
      });
    }

    // Synchronize initial TCG context so that switching tabs immediately reflects the active game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialGame = ref.read(activeGameContextProvider);
      final initialDeckFilter = ref.read(activeDeckTcgFilterProvider);
      final mappedDomain = TcgContextSync.gameToDomain(initialGame);
      if (initialDeckFilter == 'all' && mappedDomain != 'all') {
        ref.read(activeDeckTcgFilterProvider.notifier).state = mappedDomain;
      }
    });
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      final streamerSecurity = ref.read(streamerSecurityEnabledProvider);
      if (streamerSecurity) {
        ref.read(privacyModeProvider.notifier).state = true;
      }
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Continuous synchronization from Vault -> Decks
    ref.listen<String>(activeGameContextProvider, (previous, next) {
      if (previous != next) {
        final targetDomain = TcgContextSync.gameToDomain(next);
        if (ref.read(activeDeckTcgFilterProvider) != targetDomain) {
          ref.read(activeDeckTcgFilterProvider.notifier).state = targetDomain;
        }
      }
    });

    // 2. Continuous synchronization from Decks -> Vault
    ref.listen<String>(activeDeckTcgFilterProvider, (previous, next) {
      if (previous != next) {
        final targetGame = TcgContextSync.domainToGame(next);
        if (ref.read(activeGameContextProvider) != targetGame) {
          ref.read(activeGameContextProvider.notifier).state = targetGame;
        }
      }
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onBranchSelected: (index) {
          // Pre-sync context on tab switch so target screen displays the synchronized context immediately
          if (index == 2) {
            // Navigating to Decks (Branch 2): sync from Vault active game
            final currentGame = ref.read(activeGameContextProvider);
            final targetDomain = TcgContextSync.gameToDomain(currentGame);
            if (ref.read(activeDeckTcgFilterProvider) != targetDomain) {
              ref.read(activeDeckTcgFilterProvider.notifier).state = targetDomain;
            }
          } else if (index == 1) {
            // Navigating to Vault (Branch 1): sync from Decks filter
            final currentFilter = ref.read(activeDeckTcgFilterProvider);
            final targetGame = TcgContextSync.domainToGame(currentFilter);
            if (ref.read(activeGameContextProvider) != targetGame) {
              ref.read(activeGameContextProvider.notifier).state = targetGame;
            }
          }

          if (index == widget.navigationShell.currentIndex) {
            Navigator.of(context, rootNavigator: true)
                .popUntil((route) => route.isFirst);
            widget.navigationShell.goBranch(
              index,
              initialLocation: true,
            );
          } else {
            widget.navigationShell.goBranch(
              index,
              initialLocation: false,
            );
          }
        },
        onActiveBranchReselected: (index) {
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
          widget.navigationShell.goBranch(
            index,
            initialLocation: true,
          );
        },
        onScannerTap: () {
          ScannerModal.show(context);
        },
        onMenuTap: () {
          MorphingCommandCenter.show(context);
        },
      ),
    );
  }
}

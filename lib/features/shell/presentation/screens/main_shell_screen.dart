import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
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
      });
    }
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
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onBranchSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
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

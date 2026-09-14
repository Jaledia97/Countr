import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import '../widgets/custom_bottom_nav_bar.dart';

/// The Main Shell Screen wrapping the StatefulNavigationShell.
/// Hosts the persistent navigation shell and the 5-item custom bottom nav bar.
class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onBranchSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
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

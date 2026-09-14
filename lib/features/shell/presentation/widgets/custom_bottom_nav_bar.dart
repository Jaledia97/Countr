import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Custom Bottom Navigation Bar for Countr.
/// Replaces the restrictive default BottomNavigationBar.
///
/// Features 5 equally sized, flush touch targets (20% width each):
/// - Far Left (Index 0): Feed (Home Icon)
/// - Mid Left (Index 1): Vault (Safe/Folder Icon)
/// - Center (Index 2): Scanner (Camera Icon) - EXACT same size & vertical placement,
///   with contrasting highlight styling.
/// - Mid Right (Index 3): Decks (Cards Icon)
/// - Far Right (Index 4): Menu (Hamburger ☰ Icon)
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback onScannerTap;
  final VoidCallback onMenuTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onBranchSelected,
    required this.onScannerTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBarBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.navBarBorder,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Far Left (Index 0): Feed
              Expanded(
                child: _NavBarTouchTarget(
                  icon: currentIndex == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  label: 'Feed',
                  isSelected: currentIndex == 0,
                  onTap: () => onBranchSelected(0),
                ),
              ),

              // Mid Left (Index 1): Vault
              Expanded(
                child: _NavBarTouchTarget(
                  icon: currentIndex == 1
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  label: 'Vault',
                  isSelected: currentIndex == 1,
                  onTap: () => onBranchSelected(1),
                ),
              ),

              // Center (Index 2): Scanner (Exact same size and vertical placement, contrasting highlight)
              Expanded(
                child: _ScannerTouchTarget(
                  onTap: onScannerTap,
                ),
              ),

              // Mid Right (Index 3): Decks
              Expanded(
                child: _NavBarTouchTarget(
                  icon: currentIndex == 2
                      ? Icons.style_rounded
                      : Icons.style_outlined,
                  label: 'Decks',
                  isSelected: currentIndex == 2,
                  onTap: () => onBranchSelected(2),
                ),
              ),

              // Far Right (Index 4): Menu (Hamburger ☰ Icon)
              Expanded(
                child: _NavBarTouchTarget(
                  icon: Icons.menu_rounded,
                  label: 'Menu',
                  isSelected: false,
                  onTap: onMenuTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard flush touch target for Bottom Nav Bar.
class _NavBarTouchTarget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarTouchTarget({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.accentCyan : AppColors.navBarInactive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.accentCyan.withValues(alpha: 0.12),
        highlightColor: AppColors.accentCyan.withValues(alpha: 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center Scanner Touch Target:
/// Has the EXACT SAME height, vertical center alignment, and icon size (24)
/// as other touch targets, but styled with a contrasting background highlight.
class _ScannerTouchTarget extends StatelessWidget {
  final VoidCallback onTap;

  const _ScannerTouchTarget({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.accentCyan.withValues(alpha: 0.25),
        highlightColor: AppColors.accentCyan.withValues(alpha: 0.15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contrasting background highlight container keeping exact same vertical alignment
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.scannerButtonBackground,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 24, // EXACT SAME SIZE AS PEERS
                color: AppColors.scannerButtonForeground, // Contrasting dark icon
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scanner',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

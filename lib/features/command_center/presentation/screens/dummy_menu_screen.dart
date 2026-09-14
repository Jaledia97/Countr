import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Dummy branch screen for Menu required by StatefulShellRoute architecture.
/// (The actual Command Center is revealed via the Morphing Global Command Center overlay).
class DummyMenuScreen extends StatelessWidget {
  const DummyMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Menu Branch Placeholder',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

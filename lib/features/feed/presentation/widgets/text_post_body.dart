import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Body for Text Post variant.
class TextPostBody extends StatelessWidget {
  final String text;

  const TextPostBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
      child: Text(
        text,
        style: AppTypography.body.copyWith(
          fontSize: 14.5,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

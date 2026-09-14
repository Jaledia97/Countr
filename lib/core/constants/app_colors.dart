import 'package:flutter/material.dart';

/// Enterprise color palette for Countr.
/// Tailored for high-performance dark mode, trading cards, and comics.
abstract class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0C0E12);
  static const Color surface = Color(0xFF141820);
  static const Color surfaceRaised = Color(0xFF1C222C);
  static const Color surfaceHighlight = Color(0xFF252D3A);
  static const Color surfaceBorder = Color(0xFF2E3746);
  static const Color surfaceBorderSubtle = Color(0xFF222935);

  // Collector Accents
  static const Color accentAmber = Color(0xFFFF7A00); // Gold / Fire / Rare
  static const Color accentAmberLight = Color(0xFFFF9E40);
  static const Color accentViolet = Color(0xFF7B61FF); // Magic / Mythic
  static const Color accentVioletLight = Color(0xFF9B87FF);
  static const Color accentCyan = Color(0xFF00E5FF); // Scanner / Holographic
  static const Color accentCyanGlow = Color(0x3300E5FF);
  static const Color accentEmerald = Color(0xFF00E676); // Mint / Graded
  static const Color accentRose = Color(0xFFFF3366); // Hype / Likes

  // Neutrals & Typography
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDark = Color(0xFF0F172A);

  // Bottom Navigation Bar
  static const Color navBarBackground = Color(0xFF12151B);
  static const Color navBarBorder = Color(0xFF1F2530);
  static const Color navBarActive = Color(0xFF00E5FF);
  static const Color navBarInactive = Color(0xFF64748B);
  static const Color scannerButtonBackground = Color(0xFF00E5FF);
  static const Color scannerButtonForeground = Color(0xFF090B0E);
}

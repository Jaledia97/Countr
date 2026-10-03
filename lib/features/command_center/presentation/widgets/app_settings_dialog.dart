import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/state/app_state.dart';

/// Dedicated App Settings modal dialog component.
///
/// Houses core application settings (Privacy Mode, Base Currency, and
/// Streamer Security) with reactive Riverpod state updates, dark surface styling,
/// and backdrop blur.
class AppSettingsDialog extends ConsumerWidget {
  const AppSettingsDialog({super.key});

  /// Displays the [AppSettingsDialog] centered modal dialog with backdrop blur.
  static Future<T?> show<T>(BuildContext context) {
    if (!context.mounted) return Future.value(null);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss App Settings',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AppSettingsDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * curvedAnimation.value,
            sigmaY: 8 * curvedAnimation.value,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
            ),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.92,
                end: 1.0,
              ).animate(curvedAnimation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final streamerSecurityEnabled = ref.watch(streamerSecurityEnabledProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            key: const Key('command_center_app_settings_dialog'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: AppColors.accentCyan,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'APP SETTINGS',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isPrivacyMode
                                      ? AppColors.accentAmber.withValues(
                                          alpha: 0.2,
                                        )
                                      : AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isPrivacyMode ? 'PRIVACY' : 'STANDARD',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: isPrivacyMode
                                        ? AppColors.accentAmber
                                        : AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              key: const Key(
                                'command_center_app_settings_close_button',
                              ),
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.textSecondary,
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: 'Close Settings',
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 1. Global Privacy Mode Toggle
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
                              Icon(
                                isPrivacyMode
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: isPrivacyMode
                                    ? AppColors.accentAmber
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Global Privacy Mode',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Redact values and card prices',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                key: const Key(
                                  'command_center_privacy_mode_toggle',
                                ),
                                value: isPrivacyMode,
                                activeTrackColor: AppColors.accentAmber,
                                onChanged: (val) {
                                  ref.read(privacyModeProvider.notifier).state =
                                      val;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 2. Base Currency Dropdown
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1.0);
                              final isCompact =
                                  constraints.maxWidth < (60 + 170 * textScale);

                              final labelColumn = const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Base Currency',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Normalized valuation engine',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              final dropdownWidget = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.surfaceBorder,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<AppCurrency>(
                                    key: const Key(
                                      'command_center_base_currency_dropdown',
                                    ),
                                    value: baseCurrency,
                                    isDense: true,
                                    isExpanded: isCompact,
                                    dropdownColor: AppColors.surfaceRaised,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.accentCyan,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    items: AppCurrency.values.map((currency) {
                                      return DropdownMenuItem<AppCurrency>(
                                        value: currency,
                                        child: Text(
                                          '${currency.code} (${currency.symbol})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newCurrency) {
                                      if (newCurrency != null) {
                                        ref
                                                .read(
                                                  baseCurrencyProvider.notifier,
                                                )
                                                .state =
                                            newCurrency;
                                      }
                                    },
                                  ),
                                ),
                              );

                              if (isCompact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.currency_exchange_rounded,
                                          size: 20,
                                          color: AppColors.accentEmerald,
                                        ),
                                        const SizedBox(width: 10),
                                        labelColumn,
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    dropdownWidget,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  const Icon(
                                    Icons.currency_exchange_rounded,
                                    size: 20,
                                    color: AppColors.accentEmerald,
                                  ),
                                  const SizedBox(width: 10),
                                  labelColumn,
                                  dropdownWidget,
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 3. Streamer Security Toggle
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
                                Icons.security_rounded,
                                size: 20,
                                color: AppColors.accentVioletLight,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Streamer Security',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Auto-enable privacy on background',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                key: const Key(
                                  'command_center_streamer_security_toggle',
                                ),
                                value: streamerSecurityEnabled,
                                activeTrackColor: AppColors.accentVioletLight,
                                onChanged: (val) {
                                  ref
                                          .read(
                                            streamerSecurityEnabledProvider
                                                .notifier,
                                          )
                                          .state =
                                      val;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience alias/wrapper for [AppSettingsDialog].
class AppSettingsModal {
  const AppSettingsModal._();

  /// Displays the [AppSettingsDialog] centered modal dialog with backdrop blur.
  static Future<T?> show<T>(BuildContext context) =>
      AppSettingsDialog.show<T>(context);
}

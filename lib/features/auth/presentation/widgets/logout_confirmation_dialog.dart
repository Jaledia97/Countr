import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/router/app_router.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';

/// Modal confirmation dialog for logging out.
///
/// Features:
/// - Contextual prompt (Guest vs Authenticated user per Boundary B17.2)
/// - Checkbox option to keep local guest cards & decks vs reset in dev/test (F17.4)
/// - Concurrent sign-out guard (B17.1)
/// - Session clearing, auth sign-out, provider invalidation, and routing to /welcome (B17.5)
class LogoutConfirmationDialog extends ConsumerStatefulWidget {
  const LogoutConfirmationDialog({super.key});

  /// Displays the [LogoutConfirmationDialog].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LogoutConfirmationDialog(),
    );
  }

  @override
  ConsumerState<LogoutConfirmationDialog> createState() =>
      _LogoutConfirmationDialogState();
}

class _LogoutConfirmationDialogState
    extends ConsumerState<LogoutConfirmationDialog> {
  bool _keepGuestData = true;
  bool _isSigningOut = false;

  String _resolveLogoutPrompt({required bool isGuest}) {
    return isGuest
        ? 'You are browsing as Guest. Local cards can be preserved.'
        : 'Are you sure you want to log out?';
  }

  Future<void> _handleConfirmLogout() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    try {
      final db = ref.read(appDatabaseProvider);

      // 1. If user opted NOT to keep guest data (dev/test reset requested):
      if (!_keepGuestData) {
        await ref
            .read(guestMigrationServiceProvider)
            .purgeGuestData(database: db);

        // Reset preferences in dev/test
        ref.read(privacyModeProvider.notifier).state = false;
        ref.read(streamerSecurityEnabledProvider.notifier).state = false;
        ref.read(baseCurrencyProvider.notifier).state = AppCurrency.usd;
        ref.read(userPersonaProvider.notifier).state = UserPersona.investor;
      }

      // 2. Auth Sign Out (Firebase Auth / AuthRepository equivalent)
      try {
        await ref.read(authControllerProvider.notifier).signOut();
      } catch (_) {
        // Fallback to local session reset on network or auth failure (B17.4)
        ref.read(currentUserProvider.notifier).setUser(AuthUser.guest());
      }

      // 3. Clear active user session
      ref.read(currentUserProvider.notifier).setUser(AuthUser.guest());
      ref.read(currentUserIdProvider.notifier).state = 'user-current-me';

      // Invalidate UI stream providers
      ref.invalidate(userProfileProvider);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserTierProvider);
      ref.invalidate(vaultItemsStreamProvider);
      ref.invalidate(bindersStreamProvider);
      ref.invalidate(deckListProvider);
      ref.invalidate(savedPostsCountProvider);

      // 4. Pop dialogs and modal stack cleanly
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }

      // 5. Navigate to /welcome (B17.5: Post-logout navigation stack does not retain authenticated routes)
      final rootContext = rootNavigatorKey.currentContext;
      if (rootContext != null && rootContext.mounted) {
        try {
          rootContext.go('/welcome');
        } catch (_) {
          Navigator.of(rootContext)
              .pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      } else if (mounted) {
        try {
          context.go('/welcome');
        } catch (_) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(currentUserProvider);
    final prompt = _resolveLogoutPrompt(isGuest: authUser.isGuest);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.accentRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Log Out',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            key: const Key('logout_keep_guest_data_checkbox'),
            value: _keepGuestData,
            activeColor: AppColors.accentCyan,
            checkColor: AppColors.textDark,
            title: const Text(
              'Keep local guest cards & decks',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Uncheck to reset onboarding state and clear local guest collections in dev/test',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _isSigningOut
                ? null
                : (val) {
                    setState(() => _keepGuestData = val ?? true);
                  },
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          key: const Key('logout_cancel_button'),
          onPressed: _isSigningOut
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        KeyedSubtree(
          key: const Key('confirm_logout_button'),
          child: ElevatedButton(
            key: const Key('logout_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isSigningOut ? null : _handleConfirmLogout,
            child: _isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Log Out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

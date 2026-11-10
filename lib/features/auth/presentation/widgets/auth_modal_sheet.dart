import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import '../providers/auth_providers.dart';
import '../screens/business_registration_modal.dart';

/// Modal bottom sheet providing multi-provider onboarding:
/// Discord (featured CTA), Google, Apple, Facebook, Email/Password, Phone OTP,
/// Business/LGS onboarding, and Continue as Guest.
class AuthModalSheet extends ConsumerStatefulWidget {
  const AuthModalSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AuthModalSheet(),
    );
  }

  @override
  ConsumerState<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends ConsumerState<AuthModalSheet> {
  int _selectedAuthTab = 0; // 0 = Email, 1 = Phone
  bool _isSignUpMode = false;
  bool _isAwaitingPhoneOtp = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  Future<void> _handleDiscordSignIn() async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(authControllerProvider.notifier).signInWithDiscord();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(authControllerProvider.notifier).signInWithApple();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(authControllerProvider.notifier).signInWithFacebook();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() => _errorMessage = null);

    try {
      if (_isSignUpMode) {
        await ref
            .read(authControllerProvider.notifier)
            .registerWithEmail(email, password);
      } else {
        await ref
            .read(authControllerProvider.notifier)
            .signInWithEmail(email, password);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleSendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 7) {
      setState(() => _errorMessage = 'Please enter a valid phone number.');
      return;
    }

    setState(() => _errorMessage = null);
    try {
      await ref.read(authControllerProvider.notifier).sendPhoneOtp(phone);
      setState(() => _isAwaitingPhoneOtp = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleVerifyPhoneOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _phoneOtpController.text.trim();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit SMS code.');
      return;
    }

    setState(() => _errorMessage = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyPhoneOtp(phone, otp);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleOpenBusinessModal() async {
    Navigator.of(context).pop(false);
    await BusinessRegistrationModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // App Emblem & Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.accentCyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to Countr',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Sync collections, trade with friends & unlock unlimited binders',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 1. PRIMARY FEATURED CTA: Discord Button (#5865F2)
            InkWell(
              key: const Key('auth_discord_cta_button'),
              borderRadius: BorderRadius.circular(12),
              onTap: isLoading ? null : _handleDiscordSignIn,
              child: Container(
                key: const Key('auth_discord_button'),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2), // Discord Blurple
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5865F2).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Discord Gamepad/Emblem Icon
                    const Icon(
                      Icons.gamepad_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Continue with Discord',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COMMUNITY PICK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Social Buttons: Google, Apple, Facebook
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('auth_google_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.surfaceRaised,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isLoading ? null : _handleGoogleSignIn,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('G  ', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.accentCyan)),
                        Flexible(
                          child: Text(
                            'Google',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('auth_apple_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.surfaceRaised,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isLoading ? null : _handleAppleSignIn,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.apple, size: 16),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Apple',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('auth_facebook_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.surfaceRaised,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isLoading ? null : _handleFacebookSignIn,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('f  ', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                        Flexible(
                          child: Text(
                            'Meta',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Divider: OR WITH EMAIL / PHONE
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.surfaceBorder)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR WITH EMAIL / PHONE',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.surfaceBorder)),
              ],
            ),
            const SizedBox(height: 10),

            // Segmented Tab Switch: Email & Password vs Phone SMS OTP
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const Key('auth_tab_email'),
                      onTap: () => setState(() => _selectedAuthTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedAuthTab == 0 ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Email & Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedAuthTab == 0 ? AppColors.accentCyan : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const Key('auth_tab_phone'),
                      onTap: () => setState(() => _selectedAuthTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedAuthTab == 1 ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Phone SMS OTP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedAuthTab == 1 ? AppColors.accentCyan : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_selectedAuthTab == 0) ...[
              // Email & Password Fields
              TextFormField(
                key: const Key('auth_email_field'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('auth_password_field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Password (min 6 characters)',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                key: const Key('auth_submit_email_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isLoading ? null : _handleEmailSubmit,
                child: Text(
                  _isSignUpMode ? 'Create Free Account' : 'Sign In with Email',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _isSignUpMode ? 'Already have an account?' : 'Need an account?',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isSignUpMode = !_isSignUpMode),
                    child: Text(
                      _isSignUpMode ? 'Sign In' : 'Sign Up Free',
                      style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Phone SMS OTP Form
              if (!_isAwaitingPhoneOtp) ...[
                TextFormField(
                  key: const Key('auth_phone_field'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Phone number (e.g. +1 555-0199)',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceRaised,
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  key: const Key('auth_send_otp_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : _handleSendPhoneOtp,
                  child: const Text('Send SMS Code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ] else ...[
                TextFormField(
                  key: const Key('auth_otp_field'),
                  controller: _phoneOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6),
                  decoration: InputDecoration(
                    hintText: '123456',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accentCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('auth_verify_otp_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : _handleVerifyPhoneOtp,
                  child: const Text('Verify Code & Sign In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ],
            ],

            const SizedBox(height: 12),

            // Business Onboarding Link
            InkWell(
              key: const Key('auth_business_onboarding_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: _handleOpenBusinessModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: AppColors.accentAmber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Registering as a Business / Local Game Store (LGS)?',
                        style: TextStyle(
                          color: AppColors.accentAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.accentAmber, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Continue as Guest Fallback
            Center(
              child: TextButton(
                key: const Key('auth_guest_button'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Skip for now • Continue as Guest >',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

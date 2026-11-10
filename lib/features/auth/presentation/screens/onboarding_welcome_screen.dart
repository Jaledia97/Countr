import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/guest_migration_service.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

enum OnboardingAccountType {
  individual,
  business,
  guest,
}

class PlaceSuggestion {
  final String placeId;
  final String name;
  final String address;
  final String phone;
  final String website;

  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.address,
    required this.phone,
    required this.website,
  });
}

/// 3-Step Onboarding Welcome Screen (M4 / Feature 18).
///
/// Step 1: Welcome & Account Type Selection
///   - Individual Player / Collector (`Key('onboarding_account_type_individual')`)
///   - Business / Local Game Store (`Key('onboarding_account_type_business')`)
///   - Continue as Guest (`Key('onboarding_continue_as_guest')`)
///
/// Step 2 (Individual):
///   - Auth Buttons: Discord as primary CTA (`Key('onboarding_auth_discord')` & `Key('onboarding_discord_cta_button')`),
///     Google (`Key('onboarding_auth_google')`), Apple (`Key('onboarding_auth_apple')`),
///     Facebook (`Key('onboarding_auth_facebook')`), Email/Password, Phone SMS OTP.
///   - Profile Setup:
///     - Display Name (`Key('profile_setup_display_name_input')`)
///     - @username (`Key('profile_setup_username_input')`)
///     - Avatar picker (`Key('profile_setup_avatar_picker')`)
///     - Favorite Format / Commander (`Key('profile_setup_favorite_format_picker')`)
///     - Submit Button (`Key('profile_setup_submit_button')`)
///
/// Step 2 (Business):
///   - Store lookup via Google Places (`Key('business_store_lookup_input')`)
///   - Automated 6-digit OTP verification (`Key('business_otp_input')`, `Key('business_verify_otp_button')`)
///
/// Step 3: Transition to Main App Shell (`context.go('/feed')` or `/`)
///   - Enter App Button (`Key('onboarding_enter_app_button')`)
///   - Displays guest-to-registered migration summary (`Key('onboarding_migration_summary')`)
class OnboardingWelcomeScreen extends ConsumerStatefulWidget {
  final int initialStep;

  const OnboardingWelcomeScreen({
    super.key,
    this.initialStep = 0,
  });

  @override
  ConsumerState<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState
    extends ConsumerState<OnboardingWelcomeScreen> {
  late int _currentStep;
  OnboardingAccountType? _selectedAccountType;

  // Individual Form Controllers
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  String _selectedAvatarUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400';
  String _selectedFormat = 'Commander / EDH';
  int _selectedAuthTab = 0; // 0 = Email, 1 = Phone
  bool _isSignUpMode = false;
  bool _isAwaitingPhoneOtp = false;

  // Business Form Controllers
  final _storeLookupController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _storeWebsiteController = TextEditingController();
  final _businessOtpController = TextEditingController();

  // Status & Summary State
  String? _errorMessage;
  bool _isSubmitting = false;
  MigrationSummary? _migrationSummary;

  final List<PlaceSuggestion> _mockPlaces = const [
    PlaceSuggestion(
      placeId: 'place_tbs_fwb_001',
      name: 'TBS Comics - Fort Walton Beach',
      address: '68 SW Eglin Pkwy, Fort Walton Beach, FL 32548',
      phone: '(850) 244-4445',
      website: 'https://tbscomics.com',
    ),
    PlaceSuggestion(
      placeId: 'place_emerald_city_002',
      name: 'Emerald City Comics',
      address: '7744 49th St N, Pinellas Park, FL 33781',
      phone: '(727) 398-2665',
      website: 'https://emeraldcitycomics.com',
    ),
    PlaceSuggestion(
      placeId: 'place_dragons_lair_003',
      name: "Dragon's Lair Comics & Fantasy",
      address: '2457 Alamo Heights Blvd, San Antonio, TX 78209',
      phone: '(210) 829-7711',
      website: 'https://dlair.com',
    ),
  ];
  List<PlaceSuggestion> _filteredPlaces = [];

  final List<String> _formatOptions = const [
    'Commander / EDH',
    'Modern',
    'Pioneer',
    'Standard',
    'Pauper',
    'Legacy',
    'Vintage',
    'Cube',
    'Casual',
  ];

  final List<String> _avatarPresets = const [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400',
    'https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400',
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _filteredPlaces = _mockPlaces;
    _storeLookupController.addListener(_onStoreLookupChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final curUser = ref.read(currentUserProvider);
      if (!curUser.isGuest) {
        _displayNameController.text = curUser.displayName;
        _usernameController.text = curUser.username;
        if (curUser.avatarUrl != null && curUser.avatarUrl!.isNotEmpty) {
          setState(() => _selectedAvatarUrl = curUser.avatarUrl!);
        }
      } else {
        _displayNameController.text = 'Planeswalker';
        _usernameController.text = '@planeswalker';
      }
    });
  }

  void _onStoreLookupChanged() {
    final query = _storeLookupController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPlaces = _mockPlaces;
      } else {
        _filteredPlaces = _mockPlaces
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.address.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _selectPlace(PlaceSuggestion place) {
    setState(() {
      _storeLookupController.text = place.name;
      _storeAddressController.text = place.address;
      _storePhoneController.text = place.phone;
      _storeWebsiteController.text = place.website;
      _filteredPlaces = [];
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phoneOtpController.dispose();
    _storeLookupController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _storeWebsiteController.dispose();
    _businessOtpController.dispose();
    super.dispose();
  }

  void _selectAccountType(OnboardingAccountType type) {
    setState(() {
      _selectedAccountType = type;
      _errorMessage = null;
    });

    if (type == OnboardingAccountType.guest) {
      _navigateToShellOrFinish();
    } else {
      setState(() {
        _currentStep = 1;
      });
    }
  }

  Future<void> _handleDiscordSignIn() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      final user =
          await ref.read(authControllerProvider.notifier).signInWithDiscord();
      if (user != null) {
        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
          if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
            _selectedAvatarUrl = user.avatarUrl!;
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      final user =
          await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (user != null) {
        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
          if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
            _selectedAvatarUrl = user.avatarUrl!;
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      final user =
          await ref.read(authControllerProvider.notifier).signInWithApple();
      if (user != null) {
        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      final user =
          await ref.read(authControllerProvider.notifier).signInWithFacebook();
      if (user != null) {
        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleEmailAuth() async {
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

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      final user = _isSignUpMode
          ? await ref
              .read(authControllerProvider.notifier)
              .registerWithEmail(email, password)
          : await ref
              .read(authControllerProvider.notifier)
              .signInWithEmail(email, password);

      if (user != null) {
        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid phone number (min 10 digits).');
      return;
    }
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendPhoneOtp(phone);
      setState(() => _isAwaitingPhoneOtp = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleVerifyPhoneOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _phoneOtpController.text.trim();
    if (otp != '123456') {
      setState(() => _errorMessage = 'Invalid OTP code. Use 123456.');
      return;
    }
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      final user = await ref
          .read(authControllerProvider.notifier)
          .verifyPhoneOtp(phone, otp);
      if (user != null) {
        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleIndividualProfileSubmit() async {
    final displayName = _displayNameController.text.trim();
    var username = _usernameController.text.trim();

    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your display name.');
      return;
    }

    if (!username.startsWith('@') && username.isNotEmpty) {
      username = '@$username';
    }
    if (username.isEmpty) {
      username = '@collector_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    if (!RegExp(r'^@[a-zA-Z0-9_]{3,20}$').hasMatch(username)) {
      setState(() => _errorMessage =
          'Username must start with @ and be 3-20 alphanumeric characters or underscores.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authUser = ref.read(currentUserProvider);
      final effectiveId = authUser.isGuest
          ? 'user-${DateTime.now().millisecondsSinceEpoch}'
          : authUser.id;

      final updatedUser = authUser.copyWith(
        id: effectiveId,
        displayName: displayName,
        username: username,
        avatarUrl: _selectedAvatarUrl,
        isGuest: false,
        tier: authUser.isGuest ? AccountTier.free : authUser.tier,
      );

      final db = ref.read(appDatabaseProvider);
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: effectiveId,
          username: username,
          displayName: displayName,
          bio: drift.Value('Format: $_selectedFormat | Favorite Commander player.'),
          avatarUrl: drift.Value(_selectedAvatarUrl),
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          friendCount: const drift.Value(0),
          repCount: const drift.Value(0),
          tier: const drift.Value('free'),
          createdAt: DateTime.now(),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      ref.read(currentUserProvider.notifier).setUser(updatedUser);

      final migration = await ref
          .read(guestMigrationServiceProvider)
          .migrateGuestData(newUserId: effectiveId, isBusiness: false);

      setState(() {
        _migrationSummary = migration;
        _currentStep = 2; // Step 3
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleBusinessSubmitOtp() async {
    final name = _storeLookupController.text.trim();
    final address = _storeAddressController.text.trim();
    final phone = _storePhoneController.text.trim();
    final website = _storeWebsiteController.text.trim();
    final otp = _businessOtpController.text.trim();

    if (name.isEmpty || address.isEmpty || phone.isEmpty || website.isEmpty) {
      setState(() => _errorMessage = 'Please complete all store details.');
      return;
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      setState(() => _errorMessage = 'Store phone must be at least 10 digits.');
      return;
    }

    if (otp != '123456') {
      setState(() => _errorMessage = 'Invalid OTP code. Use 123456.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider.notifier).registerBusiness(
            storeName: name,
            storeAddress: address,
            storePhone: phone,
            storeWebsite: website,
            verificationCode: otp,
          );

      if (user != null) {
        final migration = await ref
            .read(guestMigrationServiceProvider)
            .migrateGuestData(newUserId: user.id, isBusiness: true);

        setState(() {
          _migrationSummary = migration;
          _currentStep = 2; // Step 3
        });
      }
    } catch (e) {
      setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _navigateToShellOrFinish() {
    try {
      context.go('/feed');
    } catch (_) {
      try {
        context.go('/');
      } catch (_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('onboarding_welcome_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: AppColors.accentCyan, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'COUNTR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_currentStep == 0) _buildStep1AccountTypeSelection(),
              if (_currentStep == 1 &&
                  _selectedAccountType == OnboardingAccountType.business)
                _buildStep2BusinessFlow(),
              if (_currentStep == 1 &&
                  _selectedAccountType != OnboardingAccountType.business)
                _buildStep2IndividualFlow(),
              if (_currentStep == 2) _buildStep3ShellTransition(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(0, 'Account Type'),
        _buildStepDivider(0),
        _buildStepDot(1, 'Setup & Auth'),
        _buildStepDivider(1),
        _buildStepDot(2, 'Launch'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppColors.accentEmerald
                  : isActive
                      ? AppColors.accentCyan
                      : AppColors.surfaceRaised,
              border: Border.all(
                color: isActive || isDone
                    ? Colors.white
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.black : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? AppColors.accentCyan : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int afterStep) {
    final isDone = _currentStep > afterStep;
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDone ? AppColors.accentEmerald : AppColors.surfaceBorder,
    );
  }

  Widget _buildStep1AccountTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Choose How You Collect',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select your account type to personalize your Countr journey.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        InkWell(
          key: const Key('onboarding_account_type_individual'),
          onTap: () => _selectAccountType(OnboardingAccountType.individual),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedAccountType == OnboardingAccountType.individual
                    ? AppColors.accentCyan
                    : AppColors.surfaceBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Individual Player / Collector',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track binders, brew decks, scan cards, and trade with community members.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        InkWell(
          key: const Key('onboarding_account_type_business'),
          onTap: () => _selectAccountType(OnboardingAccountType.business),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedAccountType == OnboardingAccountType.business
                    ? AppColors.accentAmber
                    : AppColors.surfaceBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: AppColors.accentAmber, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Business / Local Game Store',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LGS',
                            style: TextStyle(
                              color: AppColors.accentAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Store buylist, inventory management, trade verification & shop badge.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Center(
          child: TextButton.icon(
            key: const Key('onboarding_continue_as_guest'),
            onPressed: () => _selectAccountType(OnboardingAccountType.guest),
            icon: const Icon(Icons.explore_outlined,
                color: AppColors.textSecondary, size: 18),
            label: const Text(
              'Continue as Guest (Local Offline Mode)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2IndividualFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Individual Sign-In & Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Connect with your preferred platform or continue with profile setup.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 18),

        // 1. DISCORD PRIMARY CTA (#5865F2)
        KeyedSubtree(
          key: const Key('onboarding_auth_discord'),
          child: ElevatedButton(
            key: const Key('onboarding_discord_cta_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5865F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            onPressed: _isSubmitting ? null : _handleDiscordSignIn,
            child: SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gamepad_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Continue with Discord',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'COMMUNITY PICK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Social Options
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding_auth_google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.surfaceRaised,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                child: const Text('Google',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding_auth_apple'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.surfaceRaised,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _handleAppleSignIn,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, size: 16),
                    SizedBox(width: 4),
                    Text('Apple',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding_auth_facebook'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.surfaceRaised,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _handleFacebookSignIn,
                child: const Text('Facebook',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Email / Phone Accordion / Tab Section
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
                  key: const Key('onboarding_auth_email_tab'),
                  onTap: () => setState(() => _selectedAuthTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedAuthTab == 0
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Email & Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedAuthTab == 0
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  key: const Key('onboarding_auth_phone_tab'),
                  onTap: () => setState(() => _selectedAuthTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedAuthTab == 1
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Phone SMS OTP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedAuthTab == 1
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (_selectedAuthTab == 0) ...[
          TextFormField(
            key: const Key('onboarding_auth_email_input'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Email address',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceRaised,
              prefixIcon: const Icon(Icons.email_outlined,
                  color: AppColors.textSecondary, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('onboarding_auth_password_input'),
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Password (min 6 characters)',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceRaised,
              prefixIcon: const Icon(Icons.lock_outline,
                  color: AppColors.textSecondary, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  key: const Key('onboarding_auth_email_submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSubmitting ? null : _handleEmailAuth,
                  child: Text(
                    _isSignUpMode ? 'Sign Up with Email' : 'Sign In with Email',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () =>
                    setState(() => _isSignUpMode = !_isSignUpMode),
                child: Text(
                  _isSignUpMode ? 'Need Sign In?' : 'Need Account?',
                  style: const TextStyle(
                      color: AppColors.accentCyan, fontSize: 11),
                ),
              ),
            ],
          ),
        ] else ...[
          if (!_isAwaitingPhoneOtp) ...[
            TextFormField(
              key: const Key('onboarding_auth_phone_input'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Phone number (e.g. +1 555-0199)',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceRaised,
                prefixIcon: const Icon(Icons.phone_outlined,
                    color: AppColors.textSecondary, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('onboarding_auth_send_otp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.textDark,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSubmitting ? null : _handleSendPhoneOtp,
              child: const Text('Send SMS OTP',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ] else ...[
            TextFormField(
              key: const Key('onboarding_auth_otp_input'),
              controller: _phoneOtpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6),
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
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('onboarding_auth_verify_otp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.textDark,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSubmitting ? null : _handleVerifyPhoneOtp,
              child: const Text('Verify Code',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ],
        const SizedBox(height: 20),

        // Profile Setup Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COLLECTOR PROFILE SETUP',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

              // Avatar Picker
              Center(
                child: Column(
                  children: [
                    InkWell(
                      key: const Key('profile_setup_avatar_picker'),
                      onTap: () {
                        final curIdx =
                            _avatarPresets.indexOf(_selectedAvatarUrl);
                        final nextIdx = (curIdx + 1) % _avatarPresets.length;
                        setState(
                            () => _selectedAvatarUrl = _avatarPresets[nextIdx]);
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: Stack(
                        children: [
                          const CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.surfaceHighlight,
                            child: Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: AppColors.accentCyan,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.accentCyan,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to change avatar',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Display Name
              const Text(
                'DISPLAY NAME',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('profile_setup_display_name_input'),
                controller: _displayNameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. EDH Rec Fanatic',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Username (@handle)
              const Text(
                'USERNAME (@HANDLE)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('profile_setup_username_input'),
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '@username',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Favorite Format / Commander
              const Text(
                'FAVORITE FORMAT / COMMANDER',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const Key('profile_setup_favorite_format_picker'),
                initialValue: _selectedFormat,
                isExpanded: true,
                dropdownColor: AppColors.surfaceRaised,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
                items: _formatOptions
                    .map((fmt) =>
                        DropdownMenuItem(value: fmt, child: Text(fmt)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFormat = val);
                },
              ),
              const SizedBox(height: 20),

              // Submit Profile Setup
              ElevatedButton(
                key: const Key('profile_setup_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _handleIndividualProfileSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Complete Setup & Enter Countr',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2BusinessFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'LGS & Business Verification',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Connect your store details with Google Places lookup and verify store PIN.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 18),

        const Text(
          'STORE NAME (GOOGLE PLACES LOOKUP)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('business_store_lookup_input'),
          controller: _storeLookupController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search store name or address...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceRaised,
            prefixIcon: const Icon(Icons.search, color: AppColors.accentAmber),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
        ),

        if (_filteredPlaces.isNotEmpty &&
            _storeLookupController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: _filteredPlaces.map((candidate) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.storefront_rounded,
                      color: AppColors.accentAmber, size: 20),
                  title: Text(candidate.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(candidate.address,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  onTap: () => _selectPlace(candidate),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),

        const Text(
          'PHYSICAL STORE ADDRESS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('business_store_address_input'),
          controller: _storeAddressController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '68 SW Eglin Pkwy, Fort Walton Beach, FL 32548',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'STORE PHONE',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('business_store_phone_input'),
          controller: _storePhoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '(850) 244-4445',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'STORE WEBSITE',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('business_store_website_input'),
          controller: _storeWebsiteController,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'https://tbscomics.com',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.accentAmber.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AUTOMATED 6-DIGIT VERIFICATION',
                style: TextStyle(
                  color: AppColors.accentAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the 6-digit confirmation PIN (Use 123456 in dev/test bypass).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('business_otp_input'),
                controller: _businessOtpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '123456',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accentAmber),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                key: const Key('business_verify_otp_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _handleBusinessSubmitOtp,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Verify PIN & Activate LGS Profile',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3ShellTransition() {
    final curUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentEmerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 64, color: AppColors.accentEmerald),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          curUser.isVerifiedBusiness
              ? 'LGS Store Verified!'
              : curUser.isGuest
                  ? 'Welcome, Guest Collector!'
                  : 'Welcome to Countr, ${curUser.displayName}!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          curUser.isVerifiedBusiness
              ? 'Your store buylist and inventory are active with the Verified LGS badge.'
              : curUser.isGuest
                  ? 'Your offline binders and collection tools are ready to explore.'
                  : 'Your account is linked and ready for real-time portfolio management and trades.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        if (_migrationSummary != null) ...[
          Container(
            key: const Key('onboarding_migration_summary'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.accentEmerald.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sync_rounded,
                        color: AppColors.accentEmerald, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'GUEST DATA AUTO-MERGED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentEmerald,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• ${_migrationSummary!.migratedVaultItems} vault cards migrated to account\n'
                  '• ${_migrationSummary!.migratedBinders} custom binders preserved\n'
                  '• ${_migrationSummary!.migratedDecks} decks synced',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        ElevatedButton(
          key: const Key('onboarding_enter_app_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.textDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _navigateToShellOrFinish,
          child: const Text(
            'Enter App & Explore Feed',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

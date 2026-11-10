import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import '../providers/auth_providers.dart';

class PlaceCandidate {
  final String placeId;
  final String name;
  final String address;
  final String phone;
  final String website;

  const PlaceCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    required this.phone,
    required this.website,
  });
}

class BusinessRegistrationModal extends ConsumerStatefulWidget {
  const BusinessRegistrationModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BusinessRegistrationModal(),
    );
  }

  @override
  ConsumerState<BusinessRegistrationModal> createState() =>
      _BusinessRegistrationModalState();
}

class _BusinessRegistrationModalState
    extends ConsumerState<BusinessRegistrationModal> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _otpController = TextEditingController();

  final List<PlaceCandidate> _allCandidates = const [
    PlaceCandidate(
      placeId: 'places_tbs_fwb_001',
      name: 'TBS Comics - Fort Walton Beach',
      address: '68 SW Eglin Pkwy, Fort Walton Beach, FL 32548',
      phone: '(850) 244-4445',
      website: 'https://tbscomics.com',
    ),
    PlaceCandidate(
      placeId: 'places_emerald_city_002',
      name: 'Emerald City Comics',
      address: '7744 49th St N, Pinellas Park, FL 33781',
      phone: '(727) 398-2665',
      website: 'https://emeraldcitycomics.com',
    ),
    PlaceCandidate(
      placeId: 'places_dragons_lair_003',
      name: 'Dragon\'s Lair Comics & Fantasy',
      address: '2457 Alamo Heights Blvd, San Antonio, TX 78209',
      phone: '(210) 829-7711',
      website: 'https://dlair.com',
    ),
  ];

  List<PlaceCandidate> _filteredCandidates = [];
  bool _isAwaitingOtp = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _filteredCandidates = _allCandidates;
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredCandidates = _allCandidates);
    } else {
      setState(() {
        _filteredCandidates = _allCandidates
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.address.toLowerCase().contains(query))
            .toList();
      });
    }
  }

  void _selectCandidate(PlaceCandidate candidate) {
    setState(() {
      _nameController.text = candidate.name;
      _addressController.text = candidate.address;
      _phoneController.text = candidate.phone;
      _websiteController.text = candidate.website;
      _filteredCandidates = [];
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleProceedToOtp() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final website = _websiteController.text.trim();

    if (name.isEmpty || address.isEmpty || phone.isEmpty || website.isEmpty) {
      setState(() => _errorMessage = 'Please complete all store details.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isAwaitingOtp = true;
    });
    _startTimer();
  }

  Future<void> _handleSubmitVerification() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).registerBusiness(
            storeName: _nameController.text.trim(),
            storeAddress: _addressController.text.trim(),
            storePhone: _phoneController.text.trim(),
            storeWebsite: _websiteController.text.trim(),
            verificationCode: otp,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${_nameController.text.trim()}! Store verified.'),
            backgroundColor: AppColors.accentEmerald,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.accentAmber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business & LGS Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _isAwaitingOtp
                            ? 'Step 2: 6-Digit Store Verification Code'
                            : 'Step 1: Store Details & Google Places Lookup',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
              const SizedBox(height: 12),
            ],

            if (!_isAwaitingOtp) ...[
              // Store Name with Autocomplete
              const Text(
                'STORE NAME (GOOGLE PLACES LOOKUP)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('business_store_name_field'),
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. TBS Comics - Fort Walton Beach',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  prefixIcon: const Icon(Icons.search, color: AppColors.accentCyan),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),

              if (_filteredCandidates.isNotEmpty &&
                  _nameController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: _filteredCandidates.map((candidate) {
                      return ListTile(
                        key: Key('business_place_candidate_${candidate.placeId}'),
                        dense: true,
                        leading: const Icon(Icons.location_on, color: AppColors.accentCyan, size: 20),
                        title: Text(candidate.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(candidate.address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        onTap: () => _selectCandidate(candidate),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Store Address
              const Text(
                'PHYSICAL STORE ADDRESS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('business_store_address_field'),
                controller: _addressController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Street address, City, State, Zip',
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

              // Store Phone
              const Text(
                'BUSINESS PHONE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('business_store_phone_field'),
                controller: _phoneController,
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

              // Store Website
              const Text(
                'STORE WEBSITE DOMAIN',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('business_store_website_field'),
                controller: _websiteController,
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
              const SizedBox(height: 20),

              ElevatedButton(
                key: const Key('business_next_step_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleProceedToOtp,
                child: const Text('Send Store Verification PIN', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ] else ...[
              // OTP Entry
              const Text(
                'ENTER 6-DIGIT VERIFICATION CODE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We sent a 6-digit confirmation code to ${_phoneController.text.trim()} (or store domain). Use 123456 for test bypass.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('business_otp_field'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '123456',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    letterSpacing: 8,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentAmber),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isAwaitingOtp = false),
                    child: const Text('Back to Store Details', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  TextButton(
                    key: const Key('business_resend_code_button'),
                    onPressed: _resendCountdown == 0 ? _startTimer : null,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend in ${_resendCountdown}s'
                          : 'Resend Code',
                      style: TextStyle(
                        color: _resendCountdown > 0 ? AppColors.textMuted : AppColors.accentCyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                key: const Key('business_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _handleSubmitVerification,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text('Verify & Activate LGS Profile', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

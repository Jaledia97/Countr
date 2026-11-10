import 'dart:async';
import '../domain/models/auth_user.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  AuthUser _currentUser = AuthUser.guest();
  final _authStateController = StreamController<AuthUser?>.broadcast();

  MockAuthRepository({AuthUser? initialUser}) {
    if (initialUser != null) {
      _currentUser = initialUser;
    }
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  void _updateUser(AuthUser user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  Future<AuthUser> signInWithDiscord() async {
    final user = AuthUser(
      id: 'user-discord-9981',
      displayName: 'Discord Planeswalker',
      username: '@discord_champion',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      provider: AuthProviderType.discord,
      tier: AccountTier.free,
      isGuest: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final user = AuthUser(
      id: 'user-google-101',
      displayName: 'Google Collector',
      username: '@google_collector',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      provider: AuthProviderType.google,
      tier: AccountTier.free,
      isGuest: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithApple() async {
    final user = AuthUser(
      id: 'user-apple-202',
      displayName: 'Apple Collector',
      username: '@apple_player',
      provider: AuthProviderType.apple,
      tier: AccountTier.free,
      isGuest: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithFacebook() async {
    final user = AuthUser(
      id: 'user-fb-303',
      displayName: 'Meta Collector',
      username: '@fb_user',
      provider: AuthProviderType.facebook,
      tier: AccountTier.free,
      isGuest: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    if (!email.contains('@') || password.length < 6) {
      throw ArgumentError('Invalid email format or password under 6 characters.');
    }
    final name = email.split('@').first;
    final user = AuthUser(
      id: 'user-email-${email.hashCode.abs()}',
      email: email,
      displayName: name,
      username: '@$name',
      provider: AuthProviderType.email,
      tier: AccountTier.free,
      isGuest: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    return signInWithEmail(email, password);
  }

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async {
    // In mock/dev, code is dispatched instantaneously
  }

  @override
  Future<AuthUser> verifyPhoneOtp(String phoneNumber, String otp) async {
    if (otp != '123456') {
      throw ArgumentError('Invalid SMS verification code. Use 123456 for testing.');
    }
    final cleanDigits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final user = AuthUser(
      id: 'user-phone-$cleanDigits',
      phoneNumber: phoneNumber,
      displayName: 'Collector $cleanDigits',
      username: '@phone_$cleanDigits',
      provider: AuthProviderType.phone,
      tier: AccountTier.free,
      isGuest: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<AuthUser> registerBusiness({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String storeWebsite,
    required String verificationCode,
  }) async {
    if (verificationCode != '123456') {
      throw ArgumentError('Invalid store verification PIN. Use 123456 for test bypass.');
    }
    final cleanStoreSlug = storeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-');

    final user = AuthUser(
      id: 'store-$cleanStoreSlug',
      displayName: storeName,
      username: '@${storeName.replaceAll(' ', '')}',
      provider: AuthProviderType.email,
      tier: AccountTier.business,
      isGuest: false,
      isVerifiedBusiness: true,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeWebsite: storeWebsite,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _updateUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    final guest = AuthUser.guest();
    _updateUser(guest);
  }
}

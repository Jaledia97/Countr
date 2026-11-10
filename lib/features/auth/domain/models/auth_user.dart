enum AuthProviderType {
  discord,
  google,
  apple,
  facebook,
  email,
  phone,
  guest,
}

enum AccountTier {
  guest, // Max 2 custom binders, 3 decks
  free, // Max 3 custom binders, 5 decks
  pro, // Unlimited binders, unlimited decks
  business, // Unlimited binders, store buylist & inventory, verified LGS badge
}

class AuthUser {
  final String id;
  final String? email;
  final String? phoneNumber;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? bannerUrl;
  final AuthProviderType provider;
  final AccountTier tier;
  final bool isGuest;
  final bool isVerifiedBusiness;

  // Business attributes (for accountType: 'business' / AccountTier.business)
  final String? storeAddress;
  final String? storePhone;
  final String? storeWebsite;

  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const AuthUser({
    required this.id,
    this.email,
    this.phoneNumber,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.bannerUrl,
    required this.provider,
    required this.tier,
    this.isGuest = false,
    this.isVerifiedBusiness = false,
    this.storeAddress,
    this.storePhone,
    this.storeWebsite,
    required this.createdAt,
    this.lastLoginAt,
  });

  bool get isBusiness =>
      isVerifiedBusiness || tier == AccountTier.business;

  /// Default guest user factory for unauthenticated local sessions
  factory AuthUser.guest({String? guestId}) => AuthUser(
        id: guestId ?? 'guest',
        displayName: 'Guest Collector',
        username: '@guest',
        provider: AuthProviderType.guest,
        tier: AccountTier.guest,
        isGuest: true,
        createdAt: DateTime.now(),
      );

  AuthUser copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bannerUrl,
    AuthProviderType? provider,
    AccountTier? tier,
    bool? isGuest,
    bool? isVerifiedBusiness,
    String? storeAddress,
    String? storePhone,
    String? storeWebsite,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      provider: provider ?? this.provider,
      tier: tier ?? this.tier,
      isGuest: isGuest ?? this.isGuest,
      isVerifiedBusiness: isVerifiedBusiness ?? this.isVerifiedBusiness,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      storeWebsite: storeWebsite ?? this.storeWebsite,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

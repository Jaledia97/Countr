import 'auth_user.dart';

/// Represents an active authenticated session token and expiry.
class AuthSession {
  final String token;
  final AuthUser user;
  final DateTime expiresAt;

  const AuthSession({
    required this.token,
    required this.user,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

import '../domain/models/auth_user.dart';

abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser> signInWithDiscord();
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();
  Future<AuthUser> signInWithFacebook();
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> registerWithEmail(String email, String password, {String? displayName});
  Future<void> sendPhoneOtp(String phoneNumber);
  Future<AuthUser> verifyPhoneOtp(String phoneNumber, String otp);
  Future<AuthUser> registerBusiness({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String storeWebsite,
    required String verificationCode,
  });
  Future<void> signOut();
}

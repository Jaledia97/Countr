import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import '../../data/auth_repository.dart';
import '../../data/mock_auth_repository.dart';
import '../../data/guest_migration_service.dart';
import '../../domain/models/auth_user.dart';

export '../../domain/models/auth_user.dart';

/// Derived read-only provider tracking user authentication status.
final isUserLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return !user.isGuest;
});

/// Repository provider for authentication operations
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

/// Guest data migration service provider
final guestMigrationServiceProvider = Provider<GuestMigrationService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GuestMigrationService(db, ref);
});

/// Currently authenticated user. Defaults to guest.
final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, AuthUser>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return CurrentUserNotifier(repo, ref);
});

class CurrentUserNotifier extends StateNotifier<AuthUser> {
  final AuthRepository _repo;

  CurrentUserNotifier(this._repo, [Ref? _])
      : super(_repo.currentUser ?? AuthUser.guest());

  void setUser(AuthUser user) {
    state = user;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = AuthUser.guest();
  }
}

/// Controller provider handling UI auth workflows, OTP, and guest data migration trigger
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthUser?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final migrationService = ref.watch(guestMigrationServiceProvider);
  return AuthController(repo, migrationService, ref);
});

class AuthController extends StateNotifier<AsyncValue<AuthUser?>> {
  final AuthRepository _repo;
  final GuestMigrationService _migrationService;
  final Ref _ref;

  AuthController(this._repo, this._migrationService, this._ref)
      : super(const AsyncValue.data(null));

  Future<AuthUser?> _handleAuthSuccess(AuthUser user, {bool isBusiness = false}) async {
    state = AsyncValue.data(user);
    _ref.read(currentUserProvider.notifier).setUser(user);

    // Atomically migrate local guest cards, binders, decks, and votes
    try {
      await _migrationService.migrateGuestData(
        newUserId: user.id,
        isBusiness: isBusiness || user.isBusiness,
      );
    } catch (_) {}
    return user;
  }

  Future<AuthUser?> signInWithDiscord() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithDiscord();
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithGoogle();
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithApple();
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> signInWithFacebook() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithFacebook();
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithEmail(email, password);
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> registerWithEmail(String email, String password,
      {String? displayName}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.registerWithEmail(email, password,
          displayName: displayName);
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPhoneOtp(String phoneNumber) async {
    state = const AsyncValue.loading();
    try {
      await _repo.sendPhoneOtp(phoneNumber);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> verifyPhoneOtp(String phoneNumber, String otp) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.verifyPhoneOtp(phoneNumber, otp);
      return _handleAuthSuccess(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthUser?> registerBusiness({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String storeWebsite,
    required String verificationCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.registerBusiness(
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeWebsite: storeWebsite,
        verificationCode: verificationCode,
      );
      // Also update SQLite UserProfile record if present
      final db = _ref.read(appDatabaseProvider);
      await db.userProfileDao.updateBusinessVerification(
        user.id,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeWebsite: storeWebsite,
      );
      return _handleAuthSuccess(user, isBusiness: true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ref.read(currentUserProvider.notifier).signOut();
    state = const AsyncValue.data(null);
  }
}

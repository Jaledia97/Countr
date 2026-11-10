import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

final tierQuotaServiceProvider = Provider<TierQuotaService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TierQuotaService(db);
});

/// Enforces platform quotas across Unregistered Guest, Registered Free, and Pro/Business tiers.
class TierQuotaService {
  final AppDatabase _db;

  TierQuotaService(this._db);

  int maxCustomBindersFor(AccountTier tier) {
    switch (tier) {
      case AccountTier.guest:
        return 2;
      case AccountTier.free:
        return 3;
      case AccountTier.pro:
      case AccountTier.business:
        return 999999;
    }
  }

  int maxDecksFor(AccountTier tier) {
    switch (tier) {
      case AccountTier.guest:
        return 3;
      case AccountTier.free:
        return 5;
      case AccountTier.pro:
      case AccountTier.business:
        return 999999;
    }
  }

  /// Evaluates whether the active user can create another custom binder.
  /// Permanent system binders are 100% exempt from this quota.
  Future<bool> canCreateCustomBinder(dynamic ref) async {
    final AuthUser user = (ref as dynamic).read(currentUserProvider) as AuthUser;
    if (user.tier == AccountTier.pro || user.tier == AccountTier.business) {
      return true;
    }

    final currentCustomBinders = await _db.vaultDao.getCustomBinderCount(
      userId: user.isGuest ? 'guest' : user.id,
    );
    final limit = maxCustomBindersFor(user.tier);
    return currentCustomBinders < limit;
  }

  static const starterDeckIds = [
    'deck-edgar-markov',
    'deck-yuriko',
    'deck-tron',
    'deck-charizard-ex',
    'deck-lost-zone',
    'deck-lorcana',
  ];

  /// Evaluates whether the active user can create or clone another personal deck.
  Future<bool> canCreateOrCloneDeck(dynamic ref) async {
    final AuthUser user = (ref as dynamic).read(currentUserProvider) as AuthUser;
    if (user.tier == AccountTier.pro || user.tier == AccountTier.business) {
      return true;
    }

    final query = _db.select(_db.decks)
      ..where((t) => t.isDeleted.equals(false) & t.id.isNotIn(starterDeckIds));
    if (user.isGuest) {
      query.where((t) =>
          t.userId.isNull() |
          t.userId.equals('guest') |
          t.userId.equals('') |
          t.userId.like('guest%'));
    } else {
      query.where((t) => t.userId.equals(user.id));
    }
    final decks = await query.get();
    final currentDecks = decks.length;
    final limit = maxDecksFor(user.tier);
    return currentDecks < limit;
  }
}

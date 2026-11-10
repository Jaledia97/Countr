import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

class MigrationSummary {
  final int migratedVaultItems;
  final int migratedBinders;
  final int migratedDecks;
  final int migratedVotes;
  final bool isSuccess;

  const MigrationSummary({
    required this.migratedVaultItems,
    required this.migratedBinders,
    required this.migratedDecks,
    required this.migratedVotes,
    required this.isSuccess,
  });
}

class GuestMigrationService {
  final AppDatabase _db;
  final Ref _ref;

  GuestMigrationService(this._db, this._ref);

  /// Atomically migrates all local guest inventory, binders, decks, and votes
  /// to the authenticated user ID without data loss.
  Future<MigrationSummary> migrateGuestData({
    String? newUserId,
    String? registeredUserId,
    String? guestUserId,
    bool isBusiness = false,
    AppDatabase? database,
  }) async {
    final effectiveNewUserId = registeredUserId ?? newUserId;
    if (effectiveNewUserId == null ||
        effectiveNewUserId.isEmpty ||
        effectiveNewUserId == 'guest') {
      throw ArgumentError(
        'A valid non-guest newUserId or registeredUserId must be provided.',
      );
    }
    final effectiveGuestUserId = guestUserId ?? 'guest';
    final db = database ?? _db;

    final now = DateTime.now();

    final summary = await db.transaction(() async {
      // 1. Ensure permanent system binders exist for the authenticated user before cards are re-anchored
      await db.vaultDao.seedSystemBindersForUser(
        effectiveNewUserId,
        isBusiness: isBusiness,
      );

      // 2. Migrate Vault Items
      final itemsCount = await (db.update(db.vaultItems)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals(effectiveGuestUserId) |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('')))
          .write(
        VaultItemsCompanion(
          userId: Value(effectiveNewUserId),
          updatedAt: Value(now),
        ),
      );

      // 3. Migrate Vault Binders (custom binders only)
      final bindersCount = await (db.update(db.vaultBinders)
            ..where((t) =>
                t.isSystemBinder.equals(false) &
                (t.userId.isNull() |
                    t.userId.equals(effectiveGuestUserId) |
                    t.userId.equals('guest') |
                    t.userId.equals('local_user') |
                    t.userId.equals(''))))
          .write(
        VaultBindersCompanion(
          userId: Value(effectiveNewUserId),
          updatedAt: Value(now),
        ),
      );

      // 4. Re-point any cards in guest system binders to the new user's system binders
      if (isBusiness) {
        await (db.update(db.vaultItems)
              ..where((t) => t.primaryBinderId.equals('system_looking_for_guest')))
            .write(VaultItemsCompanion(
                primaryBinderId: Value('system_store_inventory_$effectiveNewUserId')));
        await (db.update(db.vaultItems)
              ..where((t) => t.primaryBinderId.equals('system_trade_block_guest')))
            .write(VaultItemsCompanion(
                primaryBinderId: Value('system_store_buylist_$effectiveNewUserId')));
      } else {
        await (db.update(db.vaultItems)
              ..where((t) => t.primaryBinderId.equals('system_looking_for_guest')))
            .write(VaultItemsCompanion(
                primaryBinderId: Value('system_looking_for_$effectiveNewUserId')));
        await (db.update(db.vaultItems)
              ..where((t) => t.primaryBinderId.equals('system_trade_block_guest')))
            .write(VaultItemsCompanion(
                primaryBinderId: Value('system_trade_block_$effectiveNewUserId')));
      }

      // Deduplicate and purge system binders to ensure invariant
      await db.vaultDao.deduplicateAndPurgeSystemBinders(effectiveNewUserId, isBusiness: isBusiness);

      // 5. Migrate Decks
      final decksCount = await (db.update(db.decks)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals(effectiveGuestUserId) |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('')))
          .write(
        DecksCompanion(
          userId: Value(effectiveNewUserId),
          updatedAt: Value(now),
        ),
      );

      // 6. Migrate Explore Deck Votes
      // Delete any guest/local votes where effectiveNewUserId already voted on that exploreDeckId
      await db.customStatement('''
        DELETE FROM explore_deck_votes 
        WHERE (user_id IN ('$effectiveGuestUserId', 'guest', 'local_user', '') OR user_id IS NULL)
          AND explore_deck_id IN (SELECT explore_deck_id FROM explore_deck_votes WHERE user_id = ?);
      ''', [effectiveNewUserId]);

      final votesCount = await (db.update(db.exploreDeckVotes)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals(effectiveGuestUserId) |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('')))
          .write(
        ExploreDeckVotesCompanion(
          userId: Value(effectiveNewUserId),
          updatedAt: Value(now),
        ),
      );

      // 7. Migrate Explore Decks author_id
      try {
        await (db.update(db.exploreDecks)
              ..where((t) =>
                  t.authorId.isNull() |
                  t.authorId.equals(effectiveGuestUserId) |
                  t.authorId.equals('guest') |
                  t.authorId.equals('local_user') |
                  t.authorId.equals('')))
            .write(
          ExploreDecksCompanion(
            authorId: Value(effectiveNewUserId),
            updatedAt: Value(now),
          ),
        );
      } catch (_) {}

      return MigrationSummary(
        migratedVaultItems: itemsCount,
        migratedBinders: bindersCount,
        migratedDecks: decksCount,
        migratedVotes: votesCount,
        isSuccess: true,
      );
    });

    // Invalidate UI stream providers so active views immediately refresh with migrated data
    try {
      if (_ref.exists(bindersStreamProvider)) _ref.invalidate(bindersStreamProvider);
      if (_ref.exists(deckListProvider)) _ref.invalidate(deckListProvider);
      if (_ref.exists(deckSummariesProvider)) _ref.invalidate(deckSummariesProvider);
      if (_ref.exists(myDecksCombinedSummariesProvider)) {
        _ref.invalidate(myDecksCombinedSummariesProvider);
      }
      if (_ref.exists(vaultItemsStreamProvider)) _ref.invalidate(vaultItemsStreamProvider);
    } catch (_) {}

    return summary;
  }

  /// Purges local guest collections, custom binders, decks, and votes from the database.
  Future<void> purgeGuestData({
    AppDatabase? database,
    String? guestUserId,
  }) async {
    final db = database ?? _db;
    final effectiveGuestUserId = guestUserId ?? 'guest';

    await db.transaction(() async {
      await (db.delete(db.vaultItems)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals(effectiveGuestUserId) |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('user-current-me') |
                t.userId.equals('')))
          .go();

      await (db.delete(db.vaultBinders)
            ..where((t) =>
                t.isSystemBinder.equals(false) &
                (t.userId.isNull() |
                    t.userId.equals(effectiveGuestUserId) |
                    t.userId.equals('guest') |
                    t.userId.equals('local_user') |
                    t.userId.equals('user-current-me') |
                    t.userId.equals(''))))
          .go();

      await (db.delete(db.decks)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals(effectiveGuestUserId) |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('user-current-me') |
                t.userId.equals('')))
          .go();

      await (db.delete(db.exploreDeckVotes)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals(effectiveGuestUserId) |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('user-current-me') |
                t.userId.equals('')))
          .go();
    });

    try {
      if (_ref.exists(bindersStreamProvider)) _ref.invalidate(bindersStreamProvider);
      if (_ref.exists(deckListProvider)) _ref.invalidate(deckListProvider);
      if (_ref.exists(deckSummariesProvider)) _ref.invalidate(deckSummariesProvider);
      if (_ref.exists(myDecksCombinedSummariesProvider)) {
        _ref.invalidate(myDecksCombinedSummariesProvider);
      }
      if (_ref.exists(vaultItemsStreamProvider)) _ref.invalidate(vaultItemsStreamProvider);
    } catch (_) {}
  }
}

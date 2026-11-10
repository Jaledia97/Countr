import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Represents a cross-user trade match between a card in user A's "Looking For"
/// binder and a card in user B's "Trade Binder".
class TradeMatchResult {
  /// Unique identifier for this match pair:
  /// 'match_${partnerUser.id}_${matchingTradeCard.id}_${lookingForCard.id}'
  final String matchId;

  /// The partner user who owns the card in their Trade Binder.
  final UserProfile partnerUser;

  /// The active trade inventory item owned by [partnerUser].
  final VaultItem matchingTradeCard;

  /// The wishlist item from the requesting user's "Looking For" binder.
  final VaultItem lookingForCard;

  /// Whether this match is mutual: [partnerUser] also has a card in their
  /// "Looking For" binder that the requesting user owns in their "Trade Binder".
  final bool isMutual;

  /// Matching criteria that triggered the match ('oracle_id', 'scryfall_id', or 'name').
  final String matchType;

  /// Timestamp when the match was evaluated.
  final DateTime detectedAt;

  const TradeMatchResult({
    required this.matchId,
    required this.partnerUser,
    required this.matchingTradeCard,
    required this.lookingForCard,
    this.isMutual = false,
    required this.matchType,
    required this.detectedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeMatchResult &&
          runtimeType == other.runtimeType &&
          matchId == other.matchId;

  @override
  int get hashCode => matchId.hashCode;
}

/// Service that cross-references cards users are looking for against
/// trade binders of other users to discover and alert on trade matches.
class TradeMatchService {
  final AppDatabase db;

  TradeMatchService(this.db);

  static const String _matchSelectQuery = '''
SELECT 
  -- Trade Item columns (Partner's card)
  ti.id AS ti_id,
  ti.name AS ti_name,
  ti.set_or_series AS ti_set_or_series,
  ti.image_url AS ti_image_url,
  ti.flavor_name AS ti_flavor_name,
  ti.acquired_price AS ti_acquired_price,
  ti.acquired_date AS ti_acquired_date,
  ti.quantity AS ti_quantity,
  ti.condition AS ti_condition,
  ti.is_graded AS ti_is_graded,
  ti.is_altered AS ti_is_altered,
  ti.is_misprint AS ti_is_misprint,
  ti.is_signed AS ti_is_signed,
  ti.personal_notes AS ti_personal_notes,
  ti.date_obtained AS ti_date_obtained,
  ti.purchase_price AS ti_purchase_price,
  ti.binder_page AS ti_binder_page,
  ti.binder_slot AS ti_binder_slot,
  ti.notes AS ti_notes,
  ti.protection_status AS ti_protection_status,
  ti.primary_binder_id AS ti_primary_binder_id,
  ti.current_market_price AS ti_current_market_price,
  ti.last_price_update AS ti_last_price_update,
  ti.dynamic_data AS ti_dynamic_data,
  ti.user_id AS ti_user_id,
  ti.is_traded AS ti_is_traded,
  ti.is_deleted AS ti_is_deleted,
  ti.updated_at AS ti_updated_at,
  ti.deleted_at AS ti_deleted_at,
  ti.sync_status AS ti_sync_status,
  ti.collection_type AS ti_collection_type,

  -- Looking For Item columns (Current User's card)
  lf.id AS lf_id,
  lf.name AS lf_name,
  lf.set_or_series AS lf_set_or_series,
  lf.image_url AS lf_image_url,
  lf.flavor_name AS lf_flavor_name,
  lf.acquired_price AS lf_acquired_price,
  lf.acquired_date AS lf_acquired_date,
  lf.quantity AS lf_quantity,
  lf.condition AS lf_condition,
  lf.is_graded AS lf_is_graded,
  lf.is_altered AS lf_is_altered,
  lf.is_misprint AS lf_is_misprint,
  lf.is_signed AS lf_is_signed,
  lf.personal_notes AS lf_personal_notes,
  lf.date_obtained AS lf_date_obtained,
  lf.purchase_price AS lf_purchase_price,
  lf.binder_page AS lf_binder_page,
  lf.binder_slot AS lf_binder_slot,
  lf.notes AS lf_notes,
  lf.protection_status AS lf_protection_status,
  lf.primary_binder_id AS lf_primary_binder_id,
  lf.current_market_price AS lf_current_market_price,
  lf.last_price_update AS lf_last_price_update,
  lf.dynamic_data AS lf_dynamic_data,
  lf.user_id AS lf_user_id,
  lf.is_traded AS lf_is_traded,
  lf.is_deleted AS lf_is_deleted,
  lf.updated_at AS lf_updated_at,
  lf.deleted_at AS lf_deleted_at,
  lf.sync_status AS lf_sync_status,
  lf.collection_type AS lf_collection_type,

  -- Partner User Profile columns
  up.id AS up_id,
  up.username AS up_username,
  up.display_name AS up_display_name,
  up.avatar_url AS up_avatar_url,
  up.account_type AS up_account_type,
  up.is_verified_business AS up_is_verified_business,
  up.friend_count AS up_friend_count,
  up.rep_count AS up_rep_count,
  up.tier AS up_tier,
  up.sync_status AS up_sync_status,
  up.collection_visibility AS up_collection_visibility,
  up.is_deleted AS up_is_deleted,
  up.created_at AS up_created_at,
  up.updated_at AS up_updated_at,
  up.deleted_at AS up_deleted_at,

  -- Matching criteria indicator
  CASE 
    WHEN json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
         AND json_extract(ti.dynamic_data, '\$.oracle_id') IS NOT NULL
         AND json_extract(ti.dynamic_data, '\$.oracle_id') = json_extract(lf.dynamic_data, '\$.oracle_id')
    THEN 'oracle_id'
    WHEN json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
         AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) IS NOT NULL
         AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) =
             COALESCE(json_extract(lf.dynamic_data, '\$.scryfall_id'), json_extract(lf.dynamic_data, '\$.id'))
    THEN 'scryfall_id'
    ELSE 'name'
  END AS match_type

FROM vault_items ti
LEFT JOIN vault_binders tb ON tb.id = ti.primary_binder_id
LEFT JOIN user_profiles up ON up.id = ti.user_id
CROSS JOIN vault_items lf
LEFT JOIN vault_binders lfb ON lfb.id = lf.primary_binder_id

WHERE 
  -- Current User's Looking For filter
  (
    lf.primary_binder_id = ('system_looking_for_' || :userId)
    OR (lfb.user_id = :userId AND lfb.system_binder_type = 'looking_for')
  )
  AND (lf.user_id = :userId OR lf.user_id IS NULL OR lf.user_id = 'local_user' OR lf.user_id = 'user-current-me')
  AND lf.is_deleted = 0

  -- Partner User's Trade Binder filter
  AND (
    ti.primary_binder_id = ('system_trade_block_' || ti.user_id)
    OR ti.primary_binder_id = ('system_store_inventory_' || ti.user_id)
    OR (tb.system_binder_type IN ('trade_block', 'store_inventory') AND tb.user_id = ti.user_id)
  )
  AND ti.user_id != :userId
  AND ti.user_id IS NOT NULL
  AND ti.user_id != 'local_user'
  AND (ti.user_id != 'user-current-me' OR :userId != 'user-current-me')
  AND ti.quantity > 0
  AND (ti.is_traded IS NULL OR ti.is_traded = 0)
  AND ti.is_deleted = 0

  -- Card Matching Predicate (oracle_id OR scryfall_id OR LOWER(name))
  AND (
    (
      json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
      AND json_extract(ti.dynamic_data, '\$.oracle_id') IS NOT NULL
      AND json_extract(ti.dynamic_data, '\$.oracle_id') = json_extract(lf.dynamic_data, '\$.oracle_id')
    )
    OR
    (
      json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
      AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) IS NOT NULL
      AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) =
          COALESCE(json_extract(lf.dynamic_data, '\$.scryfall_id'), json_extract(lf.dynamic_data, '\$.id'))
    )
    OR
    (
      LOWER(TRIM(ti.name)) = LOWER(TRIM(lf.name))
      OR (
        INSTR(ti.name, ' //') > 0
        AND LOWER(TRIM(SUBSTR(ti.name, 1, INSTR(ti.name, ' //') - 1))) = LOWER(TRIM(lf.name))
      )
      OR (
        INSTR(lf.name, ' //') > 0
        AND LOWER(TRIM(SUBSTR(lf.name, 1, INSTR(lf.name, ' //') - 1))) = LOWER(TRIM(ti.name))
      )
    )
  )
ORDER BY ti.current_market_price DESC;
''';

  VaultItem _mapTradeItem(Map<String, dynamic> data) {
    final map = <String, dynamic>{};
    data.forEach((key, value) {
      if (key.startsWith('ti_')) {
        map[key.substring(3)] = value;
      }
    });
    return db.vaultItems.map(map);
  }

  VaultItem _mapLookingForItem(Map<String, dynamic> data) {
    final map = <String, dynamic>{};
    data.forEach((key, value) {
      if (key.startsWith('lf_')) {
        map[key.substring(3)] = value;
      }
    });
    return db.vaultItems.map(map);
  }

  UserProfile _mapPartnerProfile(Map<String, dynamic> data, String partnerId) {
    final username = data['up_username'] as String?;
    if (username == null) {
      return UserProfile(
        id: partnerId,
        username: '@partner_$partnerId',
        displayName: 'Partner $partnerId',
        accountType: 'individual',
        isVerifiedBusiness: false,
        friendCount: 0,
        repCount: 0,
        tier: 'collector',
        syncStatus: 'synced',
        collectionVisibility: 'public',
        isDeleted: false,
        createdAt: DateTime.now(),
      );
    }
    final map = <String, dynamic>{};
    data.forEach((key, value) {
      if (key.startsWith('up_')) {
        map[key.substring(3)] = value;
      }
    });
    return db.userProfiles.map(map);
  }

  Future<Set<String>> _getMutualPartnerIds(
    String userId,
    Set<String> partnerIds,
  ) async {
    if (partnerIds.isEmpty) return {};

    final placeholders = List.filled(partnerIds.length, '?').join(', ');
    final sql = '''
      SELECT DISTINCT lf.user_id AS partner_user_id
      FROM vault_items ti
      LEFT JOIN vault_binders tb ON tb.id = ti.primary_binder_id
      CROSS JOIN vault_items lf
      LEFT JOIN vault_binders lfb ON lfb.id = lf.primary_binder_id
      WHERE 
        -- Current user's trade binder
        (
          ti.primary_binder_id = ('system_trade_block_' || '$userId')
          OR (tb.user_id = '$userId' AND tb.system_binder_type IN ('trade_block', 'store_inventory'))
        )
        AND (ti.user_id = '$userId' OR ti.user_id IS NULL OR ti.user_id = 'local_user' OR ti.user_id = 'user-current-me')
        AND ti.quantity > 0
        AND (ti.is_traded IS NULL OR ti.is_traded = 0)
        AND ti.is_deleted = 0
        -- Partner's looking for binder
        AND lf.user_id IN ($placeholders)
        AND (
          lf.primary_binder_id = ('system_looking_for_' || lf.user_id)
          OR (lfb.user_id = lf.user_id AND lfb.system_binder_type = 'looking_for')
        )
        AND lf.is_deleted = 0
        -- Match
        AND (
          (json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
           AND json_extract(ti.dynamic_data, '\$.oracle_id') IS NOT NULL
           AND json_extract(ti.dynamic_data, '\$.oracle_id') = json_extract(lf.dynamic_data, '\$.oracle_id'))
          OR
          (json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
           AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) IS NOT NULL
           AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) =
               COALESCE(json_extract(lf.dynamic_data, '\$.scryfall_id'), json_extract(lf.dynamic_data, '\$.id')))
          OR
          (LOWER(TRIM(ti.name)) = LOWER(TRIM(lf.name)))
          OR (
            INSTR(ti.name, ' //') > 0
            AND LOWER(TRIM(SUBSTR(ti.name, 1, INSTR(ti.name, ' //') - 1))) = LOWER(TRIM(lf.name))
          )
          OR (
            INSTR(lf.name, ' //') > 0
            AND LOWER(TRIM(SUBSTR(lf.name, 1, INSTR(lf.name, ' //') - 1))) = LOWER(TRIM(ti.name))
          )
        );
    ''';

    final rows = await db.customSelect(
      sql,
      variables: partnerIds.map((id) => Variable.withString(id)).toList(),
    ).get();

    return rows.map((r) => r.read<String>('partner_user_id')).toSet();
  }

  /// Streams active trade matches for [userId].
  Stream<List<TradeMatchResult>> watchMatchesForUser(String userId) {
    return db
        .customSelect(
          _matchSelectQuery,
          variables: [Variable.withString(userId)],
          readsFrom: {db.vaultItems, db.vaultBinders, db.userProfiles},
        )
        .watch()
        .asyncMap((rows) async {
          final rawMatches = rows.map((row) {
            final tradeCard = _mapTradeItem(row.data);
            final lookingForCard = _mapLookingForItem(row.data);
            final partner =
                _mapPartnerProfile(row.data, tradeCard.userId ?? '');
            final matchType = row.data['match_type'] as String? ?? 'name';
            return (
              partner: partner,
              tradeCard: tradeCard,
              lookingForCard: lookingForCard,
              matchType: matchType,
            );
          }).toList();

          final partnerIds = rawMatches.map((m) => m.partner.id).toSet();
          final mutualPartnerIds =
              await _getMutualPartnerIds(userId, partnerIds);

          final now = DateTime.now();
          return rawMatches.map((m) {
            final matchId =
                'match_${m.partner.id}_${m.tradeCard.id}_${m.lookingForCard.id}';
            return TradeMatchResult(
              matchId: matchId,
              partnerUser: m.partner,
              matchingTradeCard: m.tradeCard,
              lookingForCard: m.lookingForCard,
              isMutual: mutualPartnerIds.contains(m.partner.id),
              matchType: m.matchType,
              detectedAt: now,
            );
          }).toList();
        });
  }

  /// Finds reverse matches: returns cards other users are looking for
  /// that [userId] owns in their trade binder.
  Future<List<TradeMatchResult>> findReverseMatchesForUser(String userId) async {
    // Reverse matches are when another user has a Looking For item matching
    // userId's Trade Binder item.
    final sql = '''
SELECT 
  -- Trade Item columns (userId's card)
  ti.id AS ti_id,
  ti.name AS ti_name,
  ti.set_or_series AS ti_set_or_series,
  ti.image_url AS ti_image_url,
  ti.flavor_name AS ti_flavor_name,
  ti.acquired_price AS ti_acquired_price,
  ti.acquired_date AS ti_acquired_date,
  ti.quantity AS ti_quantity,
  ti.condition AS ti_condition,
  ti.is_graded AS ti_is_graded,
  ti.is_altered AS ti_is_altered,
  ti.is_misprint AS ti_is_misprint,
  ti.is_signed AS ti_is_signed,
  ti.personal_notes AS ti_personal_notes,
  ti.date_obtained AS ti_date_obtained,
  ti.purchase_price AS ti_purchase_price,
  ti.binder_page AS ti_binder_page,
  ti.binder_slot AS ti_binder_slot,
  ti.notes AS ti_notes,
  ti.protection_status AS ti_protection_status,
  ti.primary_binder_id AS ti_primary_binder_id,
  ti.current_market_price AS ti_current_market_price,
  ti.last_price_update AS ti_last_price_update,
  ti.dynamic_data AS ti_dynamic_data,
  ti.user_id AS ti_user_id,
  ti.is_traded AS ti_is_traded,
  ti.is_deleted AS ti_is_deleted,
  ti.updated_at AS ti_updated_at,
  ti.deleted_at AS ti_deleted_at,
  ti.sync_status AS ti_sync_status,
  ti.collection_type AS ti_collection_type,

  -- Looking For Item columns (Other user's card)
  lf.id AS lf_id,
  lf.name AS lf_name,
  lf.set_or_series AS lf_set_or_series,
  lf.image_url AS lf_image_url,
  lf.flavor_name AS lf_flavor_name,
  lf.acquired_price AS lf_acquired_price,
  lf.acquired_date AS lf_acquired_date,
  lf.quantity AS lf_quantity,
  lf.condition AS lf_condition,
  lf.is_graded AS lf_is_graded,
  lf.is_altered AS lf_is_altered,
  lf.is_misprint AS lf_is_misprint,
  lf.is_signed AS lf_is_signed,
  lf.personal_notes AS lf_personal_notes,
  lf.date_obtained AS lf_date_obtained,
  lf.purchase_price AS lf_purchase_price,
  lf.binder_page AS lf_binder_page,
  lf.binder_slot AS lf_binder_slot,
  lf.notes AS lf_notes,
  lf.protection_status AS lf_protection_status,
  lf.primary_binder_id AS lf_primary_binder_id,
  lf.current_market_price AS lf_current_market_price,
  lf.last_price_update AS lf_last_price_update,
  lf.dynamic_data AS lf_dynamic_data,
  lf.user_id AS lf_user_id,
  lf.is_traded AS lf_is_traded,
  lf.is_deleted AS lf_is_deleted,
  lf.updated_at AS lf_updated_at,
  lf.deleted_at AS lf_deleted_at,
  lf.sync_status AS lf_sync_status,
  lf.collection_type AS lf_collection_type,

  -- Partner User Profile columns (The other user looking for it)
  up.id AS up_id,
  up.username AS up_username,
  up.display_name AS up_display_name,
  up.avatar_url AS up_avatar_url,
  up.account_type AS up_account_type,
  up.is_verified_business AS up_is_verified_business,
  up.friend_count AS up_friend_count,
  up.rep_count AS up_rep_count,
  up.tier AS up_tier,
  up.sync_status AS up_sync_status,
  up.collection_visibility AS up_collection_visibility,
  up.is_deleted AS up_is_deleted,
  up.created_at AS up_created_at,
  up.updated_at AS up_updated_at,
  up.deleted_at AS up_deleted_at,

  -- Matching criteria indicator
  CASE 
    WHEN json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
         AND json_extract(ti.dynamic_data, '\$.oracle_id') IS NOT NULL
         AND json_extract(ti.dynamic_data, '\$.oracle_id') = json_extract(lf.dynamic_data, '\$.oracle_id')
    THEN 'oracle_id'
    WHEN json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
         AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) IS NOT NULL
         AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) =
             COALESCE(json_extract(lf.dynamic_data, '\$.scryfall_id'), json_extract(lf.dynamic_data, '\$.id'))
    THEN 'scryfall_id'
    ELSE 'name'
  END AS match_type

FROM vault_items ti
LEFT JOIN vault_binders tb ON tb.id = ti.primary_binder_id
CROSS JOIN vault_items lf
LEFT JOIN vault_binders lfb ON lfb.id = lf.primary_binder_id
LEFT JOIN user_profiles up ON up.id = lf.user_id

WHERE 
  -- Current User's Trade Binder
  (
    ti.primary_binder_id = ('system_trade_block_' || '$userId')
    OR ti.primary_binder_id = ('system_store_inventory_' || '$userId')
    OR (tb.system_binder_type IN ('trade_block', 'store_inventory') AND tb.user_id = '$userId')
  )
  AND (ti.user_id = '$userId' OR ti.user_id IS NULL OR ti.user_id = 'local_user' OR ti.user_id = 'user-current-me')
  AND ti.quantity > 0
  AND (ti.is_traded IS NULL OR ti.is_traded = 0)
  AND ti.is_deleted = 0

  -- Other User's Looking For filter
  AND lf.user_id != '$userId'
  AND lf.user_id IS NOT NULL
  AND lf.user_id != 'local_user'
  AND (lf.user_id != 'user-current-me' OR '$userId' != 'user-current-me')
  AND (
    lf.primary_binder_id = ('system_looking_for_' || lf.user_id)
    OR (lfb.user_id = lf.user_id AND lfb.system_binder_type = 'looking_for')
  )
  AND lf.is_deleted = 0

  -- Card Matching Predicate
  AND (
    (
      json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
      AND json_extract(ti.dynamic_data, '\$.oracle_id') IS NOT NULL
      AND json_extract(ti.dynamic_data, '\$.oracle_id') = json_extract(lf.dynamic_data, '\$.oracle_id')
    )
    OR
    (
      json_valid(ti.dynamic_data) = 1 AND json_valid(lf.dynamic_data) = 1
      AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) IS NOT NULL
      AND COALESCE(json_extract(ti.dynamic_data, '\$.scryfall_id'), json_extract(ti.dynamic_data, '\$.id')) =
          COALESCE(json_extract(lf.dynamic_data, '\$.scryfall_id'), json_extract(lf.dynamic_data, '\$.id'))
    )
    OR
    (
      LOWER(TRIM(ti.name)) = LOWER(TRIM(lf.name))
      OR (
        INSTR(ti.name, ' //') > 0
        AND LOWER(TRIM(SUBSTR(ti.name, 1, INSTR(ti.name, ' //') - 1))) = LOWER(TRIM(lf.name))
      )
      OR (
        INSTR(lf.name, ' //') > 0
        AND LOWER(TRIM(SUBSTR(lf.name, 1, INSTR(lf.name, ' //') - 1))) = LOWER(TRIM(ti.name))
      )
    )
  )
ORDER BY ti.current_market_price DESC;
    ''';

    final rows = await db.customSelect(sql).get();
    final now = DateTime.now();

    return rows.map((row) {
      final tradeCard = _mapTradeItem(row.data);
      final lookingForCard = _mapLookingForItem(row.data);
      final partner =
          _mapPartnerProfile(row.data, lookingForCard.userId ?? '');
      final matchType = row.data['match_type'] as String? ?? 'name';
      final matchId =
          'reverse_match_${partner.id}_${tradeCard.id}_${lookingForCard.id}';
      return TradeMatchResult(
        matchId: matchId,
        partnerUser: partner,
        matchingTradeCard: tradeCard,
        lookingForCard: lookingForCard,
        isMutual: false,
        matchType: matchType,
        detectedAt: now,
      );
    }).toList();
  }

  /// Generates an interactive notification for a trade match.
  ///
  /// Strictly adheres to self-notification safety:
  /// - [userId] is set to [recipientUserId] (the user who was looking for the card)
  /// - [actorId] is set to [match.partnerUser.id] (the partner who owns the card in trade binder)
  /// - Message format: "@UserA has [Card Name] in their Trade Binder that you have been looking for!"
  /// - Idempotent via deterministic primary key and [InsertMode.insertOrIgnore].
  Future<NotificationRecord?> generateMatchNotification(
    TradeMatchResult match, {
    required String recipientUserId,
  }) async {
    final notifId =
        'notif_match_${recipientUserId}_${match.partnerUser.id}_${match.matchingTradeCard.id}';
    final now = DateTime.now();
    final cleanUsername =
        match.partnerUser.username.replaceFirst('@', '').trim();

    final companion = NotificationsCompanion.insert(
      id: notifId,
      userId: recipientUserId,
      actorId: match.partnerUser.id,
      actorUsername: '@$cleanUsername',
      actorDisplayName: Value(match.partnerUser.displayName),
      actorAvatarUrl: Value(match.partnerUser.avatarUrl),
      type: 'trade_match',
      title: 'Trade Match Found!',
      body:
          'has ${match.matchingTradeCard.name} in their Trade Binder that you have been looking for!',
      targetEntityId: Value(match.matchingTradeCard.id),
      targetEntityType: const Value('trade_match'),
      status: const Value('unread'),
      isRead: const Value(false),
      isActioned: const Value(false),
      createdAt: Value(now),
      isDeleted: const Value(false),
      syncStatus: const Value('pending_create'),
    );

    await db
        .into(db.notifications)
        .insert(companion, mode: InsertMode.insertOrIgnore);

    return (db.select(db.notifications)..where((t) => t.id.equals(notifId)))
        .getSingleOrNull();
  }
}

/// Provider for the [TradeMatchService] instance.
final tradeMatchServiceProvider = Provider<TradeMatchService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TradeMatchService(db);
});

/// Reactive stream provider of trade matches for any specified user.
final tradeMatchesForUserProvider =
    StreamProvider.family<List<TradeMatchResult>, String>((ref, userId) {
  final service = ref.watch(tradeMatchServiceProvider);
  final effectiveId =
      userId == 'me' ? ref.watch(currentUserIdProvider) : userId;
  return service.watchMatchesForUser(effectiveId);
});

/// Reactive stream provider of trade matches for the active user.
final currentTradeMatchesProvider =
    StreamProvider<List<TradeMatchResult>>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  final service = ref.watch(tradeMatchServiceProvider);
  return service.watchMatchesForUser(currentUserId);
});

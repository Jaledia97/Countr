import 'dart:convert';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';

/// Isolated in-memory Drift database instance for E2E Production Batch tests.
AppDatabase createE2eProdBatchTestDb() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds standard mock user profiles with high-resolution avatars into [db].
Future<void> seedPersonaUserProfiles(AppDatabase db) async {
  final now = DateTime.now();
  final profiles = [
    UserProfilesCompanion.insert(
      id: 'user-spicy-brew-master',
      username: '@SpicyBrewMaster',
      displayName: 'Spicy Brewmaster',
      avatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
      accountType: const Value('individual'),
      isVerifiedBusiness: const Value(false),
      createdAt: now,
      updatedAt: Value(now),
    ),
    UserProfilesCompanion.insert(
      id: 'user-edh-rec-fanatic',
      username: '@EDH_Rec_Fanatic',
      displayName: 'EDH Rec Fanatic',
      avatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
      accountType: const Value('individual'),
      isVerifiedBusiness: const Value(false),
      createdAt: now,
      updatedAt: Value(now),
    ),
    UserProfilesCompanion.insert(
      id: 'user-foil-collector-99',
      username: '@FoilCollector99',
      displayName: 'Foil Collector 99',
      avatarUrl: const Value('https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150'),
      accountType: const Value('individual'),
      isVerifiedBusiness: const Value(false),
      createdAt: now,
      updatedAt: Value(now),
    ),
    UserProfilesCompanion.insert(
      id: 'store-tbs-comics',
      username: '@TBSComics',
      displayName: 'TBS Comics - Fort Walton Beach',
      avatarUrl: const Value('https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=150'),
      accountType: const Value('business'),
      isVerifiedBusiness: const Value(true),
      createdAt: now,
      updatedAt: Value(now),
    ),
    UserProfilesCompanion.insert(
      id: 'user-current-me',
      username: '@collector_me',
      displayName: 'Me (Current User)',
      avatarUrl: const Value('https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150'),
      accountType: const Value('individual'),
      isVerifiedBusiness: const Value(false),
      createdAt: now,
      updatedAt: Value(now),
    ),
  ];

  for (final profile in profiles) {
    await db.into(db.userProfiles).insert(profile, mode: InsertMode.insertOrReplace);
  }
}

/// Creates a standard test feed post record companion.
FeedPostsCompanion createTestFeedPostCompanion({
  required String id,
  required String authorId,
  required String authorUsername,
  required String authorDisplayName,
  String? authorAvatarUrl,
  String type = 'single_pull',
  String? textContent,
  String? cardTitle,
  String? cardSubtitle,
  String? cardImageUrl,
  String? cardId,
  String? cardRarity,
  double? estimatedValue,
  int likeCount = 0,
  int commentCount = 0,
  String? pullImagesJson,
  String? pullCardIdsJson,
}) {
  final now = DateTime.now();
  return FeedPostsCompanion.insert(
    id: id,
    authorId: authorId,
    authorUsername: authorUsername,
    authorDisplayName: authorDisplayName,
    authorAvatarUrl: Value(authorAvatarUrl),
    type: type,
    textContent: Value(textContent),
    cardTitle: Value(cardTitle),
    cardSubtitle: Value(cardSubtitle),
    cardImageUrl: Value(cardImageUrl),
    cardId: Value(cardId),
    cardRarity: Value(cardRarity),
    estimatedValue: Value(estimatedValue),
    likeCount: Value(likeCount),
    commentCount: Value(commentCount),
    pullImagesJson: Value(pullImagesJson),
    pullCardIdsJson: Value(pullCardIdsJson),
    createdAt: Value(now),
    updatedAt: Value(now),
  );
}

/// Creates a FeedPostRecord data class instance with safe defaults.
FeedPostRecord createTestFeedPostRecord({
  required String id,
  required String authorId,
  required String authorUsername,
  required String authorDisplayName,
  String? authorAvatarUrl,
  String type = 'single_pull',
  String? textContent,
  String? cardTitle,
  String? cardSubtitle,
  String? cardImageUrl,
  String? cardId,
  String? cardRarity,
  double? estimatedValue,
  int likeCount = 0,
  int commentCount = 0,
  String? pullImagesJson,
  String? pullCardIdsJson,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isDeleted = false,
  String syncStatus = 'synced',
}) {
  final now = DateTime.now();
  return FeedPostRecord(
    id: id,
    authorId: authorId,
    authorUsername: authorUsername,
    authorDisplayName: authorDisplayName,
    authorAvatarUrl: authorAvatarUrl,
    type: type,
    textContent: textContent,
    cardTitle: cardTitle,
    cardSubtitle: cardSubtitle,
    cardImageUrl: cardImageUrl,
    cardId: cardId,
    cardRarity: cardRarity,
    estimatedValue: estimatedValue,
    likeCount: likeCount,
    commentCount: commentCount,
    pullImagesJson: pullImagesJson,
    pullCardIdsJson: pullCardIdsJson,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

/// Creates and inserts a test comment into postComments table.
Future<PostCommentRecord> insertTestComment(
  AppDatabase db, {
  required String id,
  required String postId,
  required String authorId,
  required String authorUsername,
  required String authorDisplayName,
  String? authorAvatarUrl,
  required String content,
  DateTime? createdAt,
}) async {
  final now = createdAt ?? DateTime.now();
  final companion = PostCommentsCompanion.insert(
    id: id,
    postId: postId,
    authorId: authorId,
    authorUsername: authorUsername,
    authorDisplayName: authorDisplayName,
    authorAvatarUrl: Value(authorAvatarUrl),
    content: content,
    createdAt: Value(now),
    updatedAt: Value(now),
  );
  await db.into(db.postComments).insert(companion);
  return (db.select(db.postComments)..where((t) => t.id.equals(id))).getSingle();
}

/// Helper to create a comprehensive VaultItem for test purposes.
VaultItem createTestVaultCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'LTR',
  String? setCode = 'ltr',
  String? primaryBinderId,
  String? userId = 'user-current-me',
  int quantity = 1,
  double acquiredPrice = 10.0,
  double currentMarketPrice = 15.0,
  String condition = 'NM',
  String? imageUrl,
  String? oracleText = 'Test oracle text',
  String? manaCost = '{2}{U}',
  double? cmc = 3.0,
  String? typeLine = 'Creature',
  String? rarity = 'rare',
  bool isTraded = false,
  bool isDeleted = false,
  Map<String, dynamic>? extraDynamicData,
}) {
  final dynamicMap = <String, dynamic>{
    'oracle_text': oracleText,
    'mana_cost': manaCost,
    'cmc': cmc,
    'type_line': typeLine,
    'rarity': rarity,
    'set': (setCode ?? setOrSeries).toLowerCase(),
    'set_code': (setCode ?? setOrSeries).toLowerCase(),
    'set_name': setOrSeries,
    'collector_number': '101',
    'image_uris': {
      'normal': imageUrl ?? 'https://cards.scryfall.io/normal/front/1/2/12345678.jpg',
      'large': imageUrl ?? 'https://cards.scryfall.io/large/front/1/2/12345678.jpg',
    },
  };
  if (extraDynamicData != null) {
    dynamicMap.addAll(extraDynamicData);
  }

  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl ?? 'https://cards.scryfall.io/normal/front/1/2/12345678.jpg',
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime.now(),
    quantity: quantity,
    condition: condition,
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    isDeleted: isDeleted,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime.now(),
    primaryBinderId: primaryBinderId,
    userId: userId,
    isTraded: isTraded,
    dynamicData: jsonEncode(dynamicMap),
  );
}

/// Helper to create a test ExploreDeck.
ExploreDeck createTestExploreDeckRecord({
  required String id,
  required String name,
  String format = 'Commander',
  String tcgDomain = 'mtg',
  String sourceType = 'community',
  String creatorName = '@SpicyBrewMaster',
  String? authorId = 'user-spicy-brew-master',
  String? commanderName = 'The Ur-Dragon',
  String? commanderImageUrl = 'https://cards.scryfall.io/normal/front/7/2/722b1f02-c4e1-4dfd-8c4f-963233432d45.jpg',
  String? commanderArtCrop,
  int cardCount = 100,
  double estimatedPrice = 149.99,
  int upvotes = 10,
  int downvotes = 1,
  int? score,
  String colorIdentity = '["W","U","B","R","G"]',
  bool isDeleted = false,
}) {
  final now = DateTime.now();
  return ExploreDeck(
    id: id,
    name: name,
    format: format,
    tcgDomain: tcgDomain,
    sourceType: sourceType,
    creatorName: creatorName,
    authorId: authorId,
    commanderName: commanderName,
    commanderImageUrl: commanderImageUrl,
    commanderArtCrop: commanderArtCrop,
    cardCount: cardCount,
    estimatedPrice: estimatedPrice,
    upvotes: upvotes,
    downvotes: downvotes,
    score: score ?? (upvotes - downvotes),
    colorIdentity: colorIdentity,
    createdAt: now,
    updatedAt: now,
    isDeleted: isDeleted,
  );
}

/// Wraps widget under test in MaterialApp and ProviderScope.
Widget wrapWithMaterialAndScope(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

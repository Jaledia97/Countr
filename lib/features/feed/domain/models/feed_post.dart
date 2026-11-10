import 'dart:convert';
import '../../../../core/database/app_database.dart';

enum PostType {
  text,
  singlePull,
  multiPull,
  media,
  mixedMedia,
}

class FeedPost {
  final String id;
  final PostType type;
  final String? authorId;
  final String? sharedByUserId;
  final String username;
  final String? authorDisplayName;
  final String avatarInitials;
  final String? avatarUrl;
  final String timestamp;
  final String locationTag;
  final String? textContent;
  final String? cardId;
  final String? cardTitle;
  final String? cardSubtitle;
  final String? cardRarity;
  final String? estimatedValue;
  final String? cardImageUrl;
  final List<String> pullImages;
  final List<String> pullCardIds;
  final int hypeCount;
  final int commentCount;
  final bool isHyped;
  final bool isWishlisted;

  const FeedPost({
    required this.id,
    required this.type,
    this.authorId,
    this.sharedByUserId,
    required this.username,
    this.authorDisplayName,
    required this.avatarInitials,
    this.avatarUrl,
    required this.timestamp,
    required this.locationTag,
    this.textContent,
    this.cardId,
    this.cardTitle,
    this.cardSubtitle,
    this.cardRarity,
    this.estimatedValue,
    this.cardImageUrl,
    this.pullImages = const [],
    this.pullCardIds = const [],
    this.hypeCount = 0,
    this.commentCount = 0,
    this.isHyped = false,
    this.isWishlisted = false,
  });

  /// Resolves canonical user profile ID for profile routing.
  String get effectiveAuthorId {
    if (authorId != null && authorId!.isNotEmpty) return authorId!;
    final clean = username.replaceAll('@', '').toLowerCase();
    if (clean.contains('edh')) return 'user-edh-rec-fanatic';
    if (clean.contains('spicy')) return 'user-spicy-brew-master';
    if (clean.contains('foil')) return 'user-foil-collector-99';
    if (clean.contains('tbs')) return 'store-tbs-comics';
    return 'user-current-me';
  }

  factory FeedPost.fromRecord(FeedPostRecord record, {bool isHyped = false}) {
    PostType resolvedType = PostType.text;
    if (record.type == 'single_pull' || record.type == 'singleCard') {
      resolvedType = PostType.singlePull;
    } else if (record.type == 'multi_pull' || record.type == 'multiCard') {
      resolvedType = PostType.multiPull;
    } else if (record.type == 'media' || record.type == 'image') {
      resolvedType = PostType.media;
    } else if (record.type == 'mixed_media' || record.type == 'mixedMedia') {
      resolvedType = PostType.mixedMedia;
    }

    List<String> images = [];
    if (record.pullImagesJson != null && record.pullImagesJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(record.pullImagesJson!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    List<String> cardIds = [];
    if (record.pullCardIdsJson != null && record.pullCardIdsJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(record.pullCardIdsJson!);
        if (decoded is List) {
          cardIds = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    // Initials from username or display name
    String initials = 'U';
    final name = record.authorDisplayName.isNotEmpty
        ? record.authorDisplayName
        : record.authorUsername;
    final clean = name.replaceAll('@', '').trim();
    if (clean.isNotEmpty) {
      final parts = clean.split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    // Relative timestamp display
    final diff = DateTime.now().difference(record.createdAt);
    String timeStr = 'Just now';
    if (diff.inDays > 0) {
      timeStr = '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      timeStr = '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      timeStr = '${diff.inMinutes}m ago';
    }

    // High-resolution avatar fallback for seeded mock personas if missing
    String? resolvedAvatarUrl = record.authorAvatarUrl;
    if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
      final lowerUsername = record.authorUsername.toLowerCase();
      final lowerAuthorId = record.authorId.toLowerCase();
      if (lowerUsername.contains('edh') || lowerAuthorId.contains('edh')) {
        resolvedAvatarUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80';
      } else if (lowerUsername.contains('spicy') || lowerAuthorId.contains('spicy')) {
        resolvedAvatarUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80';
      } else if (lowerUsername.contains('foil') || lowerAuthorId.contains('foil')) {
        resolvedAvatarUrl = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80';
      } else if (lowerUsername.contains('tbs') || lowerAuthorId.contains('tbs')) {
        resolvedAvatarUrl = 'https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80';
      } else if (lowerUsername.contains('collector_me') || lowerAuthorId.contains('current-me')) {
        resolvedAvatarUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80';
      }
    }

    return FeedPost(
      id: record.id,
      type: resolvedType,
      authorId: record.authorId,
      sharedByUserId: record.sharedByUserId,
      username: record.authorUsername,
      authorDisplayName: record.authorDisplayName,
      avatarInitials: initials,
      avatarUrl: resolvedAvatarUrl,
      timestamp: timeStr,
      locationTag: record.locationTag ?? 'Local Game Store',
      textContent: record.textContent,
      cardId: record.cardId,
      cardTitle: record.cardTitle,
      cardSubtitle: record.cardSubtitle,
      cardRarity: record.cardRarity,
      estimatedValue: record.estimatedValue != null
          ? '\$${record.estimatedValue!.toStringAsFixed(2)}'
          : null,
      cardImageUrl: record.cardImageUrl,
      pullImages: images,
      pullCardIds: cardIds,
      hypeCount: record.likeCount,
      commentCount: record.commentCount,
      isHyped: isHyped,
    );
  }

  FeedPost copyWith({
    String? id,
    PostType? type,
    String? authorId,
    String? sharedByUserId,
    String? username,
    String? authorDisplayName,
    String? avatarInitials,
    String? avatarUrl,
    String? timestamp,
    String? locationTag,
    String? textContent,
    String? cardId,
    String? cardTitle,
    String? cardSubtitle,
    String? cardRarity,
    String? estimatedValue,
    String? cardImageUrl,
    List<String>? pullImages,
    List<String>? pullCardIds,
    int? hypeCount,
    int? commentCount,
    bool? isHyped,
    bool? isWishlisted,
  }) {
    return FeedPost(
      id: id ?? this.id,
      type: type ?? this.type,
      authorId: authorId ?? this.authorId,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      username: username ?? this.username,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timestamp: timestamp ?? this.timestamp,
      locationTag: locationTag ?? this.locationTag,
      textContent: textContent ?? this.textContent,
      cardId: cardId ?? this.cardId,
      cardTitle: cardTitle ?? this.cardTitle,
      cardSubtitle: cardSubtitle ?? this.cardSubtitle,
      cardRarity: cardRarity ?? this.cardRarity,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      cardImageUrl: cardImageUrl ?? this.cardImageUrl,
      pullImages: pullImages ?? this.pullImages,
      pullCardIds: pullCardIds ?? this.pullCardIds,
      hypeCount: hypeCount ?? this.hypeCount,
      commentCount: commentCount ?? this.commentCount,
      isHyped: isHyped ?? this.isHyped,
      isWishlisted: isWishlisted ?? this.isWishlisted,
    );
  }
}

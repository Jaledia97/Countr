enum PostType {
  text,
  singlePull,
  multiPull,
}

class FeedPost {
  final String id;
  final PostType type;
  final String username;
  final String avatarInitials;
  final String timestamp;
  final String locationTag;
  final String? textContent;
  final String? cardTitle;
  final String? cardSubtitle;
  final String? cardRarity;
  final String? estimatedValue;
  final List<String> pullImages;
  final int hypeCount;
  final int commentCount;
  final bool isHyped;
  final bool isWishlisted;

  const FeedPost({
    required this.id,
    required this.type,
    required this.username,
    required this.avatarInitials,
    required this.timestamp,
    required this.locationTag,
    this.textContent,
    this.cardTitle,
    this.cardSubtitle,
    this.cardRarity,
    this.estimatedValue,
    this.pullImages = const [],
    this.hypeCount = 0,
    this.commentCount = 0,
    this.isHyped = false,
    this.isWishlisted = false,
  });

  FeedPost copyWith({
    String? id,
    PostType? type,
    String? username,
    String? avatarInitials,
    String? timestamp,
    String? locationTag,
    String? textContent,
    String? cardTitle,
    String? cardSubtitle,
    String? cardRarity,
    String? estimatedValue,
    List<String>? pullImages,
    int? hypeCount,
    int? commentCount,
    bool? isHyped,
    bool? isWishlisted,
  }) {
    return FeedPost(
      id: id ?? this.id,
      type: type ?? this.type,
      username: username ?? this.username,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      timestamp: timestamp ?? this.timestamp,
      locationTag: locationTag ?? this.locationTag,
      textContent: textContent ?? this.textContent,
      cardTitle: cardTitle ?? this.cardTitle,
      cardSubtitle: cardSubtitle ?? this.cardSubtitle,
      cardRarity: cardRarity ?? this.cardRarity,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      pullImages: pullImages ?? this.pullImages,
      hypeCount: hypeCount ?? this.hypeCount,
      commentCount: commentCount ?? this.commentCount,
      isHyped: isHyped ?? this.isHyped,
      isWishlisted: isWishlisted ?? this.isWishlisted,
    );
  }
}

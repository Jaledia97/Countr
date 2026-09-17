/// Data model representing an official ruling for a Magic: The Gathering card
/// retrieved from the Scryfall API (/cards/{id}/rulings).
class ScryfallRuling {
  final String? oracleId;
  final String source;
  final String publishedAt;
  final String comment;

  const ScryfallRuling({
    this.oracleId,
    this.source = 'wotc',
    required this.publishedAt,
    required this.comment,
  });

  factory ScryfallRuling.fromJson(Map<String, dynamic> json) {
    return ScryfallRuling(
      oracleId: json['oracle_id'] as String?,
      source: (json['source'] as String?) ?? 'wotc',
      publishedAt: (json['published_at'] as String?) ??
          (json['publishedAt'] as String?) ??
          '',
      comment: (json['comment'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    if (oracleId != null) 'oracle_id': oracleId,
    'source': source,
    'published_at': publishedAt,
    'comment': comment,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScryfallRuling &&
          runtimeType == other.runtimeType &&
          oracleId == other.oracleId &&
          source == other.source &&
          publishedAt == other.publishedAt &&
          comment == other.comment;

  @override
  int get hashCode =>
      oracleId.hashCode ^
      source.hashCode ^
      publishedAt.hashCode ^
      comment.hashCode;

  @override
  String toString() =>
      'ScryfallRuling(publishedAt: $publishedAt, comment: $comment)';
}

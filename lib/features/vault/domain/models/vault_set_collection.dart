import 'package:flutter/foundation.dart';

/// Domain model representing a card set collection (e.g., "The Lord of the Rings: Tales of Middle-earth")
/// with completion progress metrics computed from the Vault database.
@immutable
class VaultSetCollection {
  final String setName;
  final String setCode;
  final String collectionType;
  final int totalCount;
  final int ownedCount;
  final double completionPercentage; // 0.0 to 1.0
  final String? sampleImageUrl;
  final String? releaseDate;

  const VaultSetCollection({
    required this.setName,
    required this.setCode,
    required this.collectionType,
    required this.totalCount,
    required this.ownedCount,
    required this.completionPercentage,
    this.sampleImageUrl,
    this.releaseDate,
  });

  /// Returns true if all unique cards in the set have been collected (ownedCount >= totalCount).
  bool get isComplete => totalCount > 0 && ownedCount >= totalCount;

  VaultSetCollection copyWith({
    String? setName,
    String? setCode,
    String? collectionType,
    int? totalCount,
    int? ownedCount,
    double? completionPercentage,
    String? sampleImageUrl,
    String? releaseDate,
  }) {
    return VaultSetCollection(
      setName: setName ?? this.setName,
      setCode: setCode ?? this.setCode,
      collectionType: collectionType ?? this.collectionType,
      totalCount: totalCount ?? this.totalCount,
      ownedCount: ownedCount ?? this.ownedCount,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      sampleImageUrl: sampleImageUrl ?? this.sampleImageUrl,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultSetCollection &&
          runtimeType == other.runtimeType &&
          setName == other.setName &&
          setCode == other.setCode &&
          collectionType == other.collectionType &&
          totalCount == other.totalCount &&
          ownedCount == other.ownedCount &&
          completionPercentage == other.completionPercentage &&
          sampleImageUrl == other.sampleImageUrl &&
          releaseDate == other.releaseDate;

  @override
  int get hashCode => Object.hash(
        setName,
        setCode,
        collectionType,
        totalCount,
        ownedCount,
        completionPercentage,
        sampleImageUrl,
        releaseDate,
      );

  @override
  String toString() =>
      'VaultSetCollection(setName: $setName, setCode: $setCode, collectionType: $collectionType, totalCount: $totalCount, ownedCount: $ownedCount, completionPercentage: $completionPercentage, releaseDate: $releaseDate)';
}

// Copyright (c) 2026 Countr. All rights reserved.
import 'package:flutter/foundation.dart';
import '../../../life_counter/domain/models/pod_state.dart';

/// Represents a player queued in the waitlist for the next group game.
@immutable
class WaitlistQueueEntry {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? deckId;
  final String? deckName;
  final String? commanderCardId;
  final String? commanderName;
  final String? commanderArtCropUrl;
  final DateTime joinedAt;

  const WaitlistQueueEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.deckId,
    this.deckName,
    this.commanderCardId,
    this.commanderName,
    this.commanderArtCropUrl,
    required this.joinedAt,
  });

  WaitlistQueueEntry copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? deckId,
    String? deckName,
    String? commanderCardId,
    String? commanderName,
    String? commanderArtCropUrl,
    DateTime? joinedAt,
  }) {
    return WaitlistQueueEntry(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      deckId: deckId ?? this.deckId,
      deckName: deckName ?? this.deckName,
      commanderCardId: commanderCardId ?? this.commanderCardId,
      commanderName: commanderName ?? this.commanderName,
      commanderArtCropUrl: commanderArtCropUrl ?? this.commanderArtCropUrl,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'deckId': deckId,
        'deckName': deckName,
        'commanderCardId': commanderCardId,
        'commanderName': commanderName,
        'commanderArtCropUrl': commanderArtCropUrl,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory WaitlistQueueEntry.fromJson(Map<String, dynamic> json) =>
      WaitlistQueueEntry(
        userId: json['userId'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        deckId: json['deckId'] as String?,
        deckName: json['deckName'] as String?,
        commanderCardId: json['commanderCardId'] as String?,
        commanderName: json['commanderName'] as String?,
        commanderArtCropUrl: json['commanderArtCropUrl'] as String?,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );
}

/// Represents an active or queued in-store MTG group pod.
@immutable
class GroupPodGame {
  final String id;
  final String title;
  final String location;
  final String format;
  final String status;
  final int maxSeats;
  final int startingLife;
  final List<PodPlayerState> seatedPlayers;
  final List<WaitlistQueueEntry> waitlistQueue;

  const GroupPodGame({
    required this.id,
    required this.title,
    required this.location,
    this.format = 'Commander',
    this.status = 'Game in Progress',
    this.maxSeats = 4,
    this.startingLife = 40,
    this.seatedPlayers = const [],
    this.waitlistQueue = const [],
  });

  bool get isFull => seatedPlayers.length >= maxSeats;
  int get waitlistCount => waitlistQueue.length;

  bool isUserQueued(String userId) {
    return waitlistQueue.any((entry) => entry.userId == userId);
  }

  int queuePosition(String userId) {
    final idx = waitlistQueue.indexWhere((entry) => entry.userId == userId);
    return idx >= 0 ? idx + 1 : 0;
  }

  GroupPodGame copyWith({
    String? id,
    String? title,
    String? location,
    String? format,
    String? status,
    int? maxSeats,
    int? startingLife,
    List<PodPlayerState>? seatedPlayers,
    List<WaitlistQueueEntry>? waitlistQueue,
  }) {
    return GroupPodGame(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      format: format ?? this.format,
      status: status ?? this.status,
      maxSeats: maxSeats ?? this.maxSeats,
      startingLife: startingLife ?? this.startingLife,
      seatedPlayers: seatedPlayers ?? this.seatedPlayers,
      waitlistQueue: waitlistQueue ?? this.waitlistQueue,
    );
  }
}

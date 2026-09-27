import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/matches/match_sessions_table.dart';

/// Drift Table representing an append-only transaction event in a match session.
///
/// Supports commutative event sourcing for P2P synchronization, life delta ledgers,
/// commander damage tracking, counter adjustments, storm/mana history, and undo support.
@DataClassName('MatchEvent')
class MatchEvents extends Table {
  /// Unique event identifier (UUID v4)
  TextColumn get id => text()();

  /// Foreign key referencing parent match session
  TextColumn get sessionId =>
      text().named('session_id').references(MatchSessions, #id)();

  /// Target player receiving the adjustment (or session/table identifier for global events)
  TextColumn get playerId => text().named('player_id')();

  /// Source player inflicting damage or causing the effect (e.g. opposing commander damage dealer)
  TextColumn get sourcePlayerId =>
      text().named('source_player_id').nullable()();

  /// Event type identifier:
  /// - 'session_created'
  /// - 'life_delta'
  /// - 'commander_damage'
  /// - 'poison'
  /// - 'energy'
  /// - 'experience'
  /// - 'commander_tax'
  /// - 'monarch'
  /// - 'initiative'
  /// - 'day_night'
  /// - 'mana_change'
  /// - 'mana_clear'
  /// - 'storm'
  /// - 'dice_roll'
  /// - 'coin_flip'
  /// - 'reset'
  /// - 'undo'
  TextColumn get eventType => text().named('event_type')();

  /// Integer delta for this event (e.g. +3, -5, +1 poison)
  IntColumn get delta =>
      integer().withDefault(const Constant(0))();

  /// Resulting or absolute value after applying the delta
  IntColumn get value =>
      integer().withDefault(const Constant(0))();

  /// Monotonically increasing sequence number assigned by host authority for P2P ordering
  IntColumn get sequenceNumber =>
      integer().named('sequence_number').withDefault(const Constant(0))();

  /// Extended payload for structured details (e.g. dice roll sides/results, mana color, coin result)
  TextColumn get payloadJson =>
      text().named('payload_json').nullable()();

  /// Timestamp when event occurred
  DateTimeColumn get timestamp => dateTime()();

  /// True if this event was undone by the player
  BoolColumn get isUndone =>
      boolean().named('is_undone').withDefault(const Constant(false))();

  // Drift v9+ Soft Delete & Outbox Invariants
  /// Soft deletion flag for offline-first data retention
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  /// Timestamp of last modification for sync conflict resolution
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';

/// Drift Table representing an active or historical MTG life counter match session.
///
/// Tracks match configuration, format, starting life, participant count,
/// network host status, room code, and lifecycle status ('active', 'completed', 'abandoned').
@DataClassName('MatchSession')
class MatchSessions extends Table {
  /// Unique session identifier (UUID v4)
  TextColumn get id => text()();

  /// Human-readable match name (e.g. "Commander Night - Pod 1")
  TextColumn get name => text().withDefault(const Constant('MTG Match'))();

  /// Match format (e.g. 'Commander', 'Standard', 'Brawl', 'Draft', 'Modern', 'Two-Headed Giant', 'Custom')
  TextColumn get format => text().withDefault(const Constant('Commander'))();

  /// Starting life total per player (e.g. 40 for Commander, 20 for Standard, 30 for Brawl)
  IntColumn get startingLife =>
      integer().named('starting_life').withDefault(const Constant(40))();

  /// Total number of player seats configured for this session (1..6)
  IntColumn get playerCount =>
      integer().named('player_count').withDefault(const Constant(4))();

  /// Lifecycle status: 'active', 'completed', 'abandoned'
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Timestamp when match was created
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Timestamp when match ended or was abandoned
  DateTimeColumn get endedAt => dateTime().named('ended_at').nullable()();

  /// True if this device is the P2P host authority for this match
  BoolColumn get isP2pHost =>
      boolean().named('is_p2p_host').withDefault(const Constant(false))();

  /// 5-character alphanumeric room code for P2P mesh discovery and direct connect
  TextColumn get p2pSessionCode =>
      text().named('p2p_session_code').nullable()();

  /// Arbitrary JSON configuration payload for extensible session settings
  TextColumn get settingsJson =>
      text().named('settings_json').nullable()();

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

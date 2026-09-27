import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/matches/match_sessions_table.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';

/// Drift Table representing a player seat in an MTG life counter match.
///
/// Stores player identity, profile/deck links, commander imagery,
/// current life total, secondary counters, and player status.
@DataClassName('MatchPlayer')
class MatchPlayers extends Table {
  /// Unique player seat identifier (UUID v4)
  TextColumn get id => text()();

  /// Foreign key referencing parent match session
  TextColumn get sessionId =>
      text().named('session_id').references(MatchSessions, #id)();

  /// 0-indexed seating order in pod grid (0..playerCount - 1)
  IntColumn get seatOrder => integer().named('seat_order')();

  /// Display name of the player
  TextColumn get playerName => text().named('player_name')();

  /// Optional foreign key to a local constructed deck from Vault
  TextColumn get deckId =>
      text().named('deck_id').nullable().references(Decks, #id)();

  /// Optional foreign key to commander card in VaultItems
  TextColumn get commanderCardId =>
      text().named('commander_card_id').nullable().references(VaultItems, #id)();

  /// Commander card name (e.g. "Atraxa, Praetors' Voice")
  TextColumn get commanderName =>
      text().named('commander_name').nullable()();

  /// High-resolution art crop URL for dynamic quadrant background
  TextColumn get artCropUrl =>
      text().named('art_crop_url').nullable()();

  /// Primary color theme / MTG color identity string (e.g. "WUBG")
  TextColumn get colorTheme =>
      text().named('color_theme').nullable()();

  /// Current life total
  IntColumn get currentLife =>
      integer().named('current_life').withDefault(const Constant(40))();

  /// Poison counters (10 = lethal defeat in standard/commander rules)
  IntColumn get poison =>
      integer().withDefault(const Constant(0))();

  /// Energy counters ({E})
  IntColumn get energy =>
      integer().withDefault(const Constant(0))();

  /// Experience counters (XP)
  IntColumn get experience =>
      integer().withDefault(const Constant(0))();

  /// Additional commander tax in generic mana (+2 per previous cast)
  IntColumn get commanderTax =>
      integer().named('commander_tax').withDefault(const Constant(0))();

  /// True if this player is currently the Monarch
  BoolColumn get isMonarch =>
      boolean().named('is_monarch').withDefault(const Constant(false))();

  /// True if this player currently holds the Initiative
  BoolColumn get hasInitiative =>
      boolean().named('has_initiative').withDefault(const Constant(false))();

  /// True if this player has been eliminated from the match
  BoolColumn get isEliminated =>
      boolean().named('is_eliminated').withDefault(const Constant(false))();

  /// Timestamp when player was eliminated (or null if still active)
  DateTimeColumn get eliminatedAt =>
      dateTime().named('eliminated_at').nullable()();

  /// True if this player is running on the local device; false if connected via P2P
  BoolColumn get isLocalDevice =>
      boolean().named('is_local_device').withDefault(const Constant(true))();

  /// Network peer device identifier if connected via P2P
  TextColumn get peerDeviceId =>
      text().named('peer_device_id').nullable()();

  /// JSON map of commander damage taken from opponents: `{"opponentPlayerId": 14}`
  TextColumn get commanderDamageJson =>
      text().named('commander_damage_json').nullable()();

  /// JSON map of floating mana per color: `{"W":0,"U":1,"B":0,"R":2,"G":0,"C":0}`
  TextColumn get floatingManaJson =>
      text().named('floating_mana_json').nullable()();

  /// Storm count for current phase/turn
  IntColumn get stormCount =>
      integer().named('storm_count').withDefault(const Constant(0))();

  /// Arbitrary JSON map for secondary or custom counters
  TextColumn get countersJson =>
      text().named('counters_json').nullable()();

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

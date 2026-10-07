import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/explore_decks_table.dart';

/// Drift Table representing an individual card entry within an Explore Deck.
///
/// Stores card metadata, Scryfall references, board zone, mana attributes,
/// and pricing independent of user vault items.
@DataClassName('ExploreDeckItem')
class ExploreDeckItems extends Table {
  /// Unique item identifier (UUID v4 or structured slug)
  TextColumn get id => text()();

  /// Foreign key referencing parent ExploreDeck
  TextColumn get exploreDeckId => text()
      .named('explore_deck_id')
      .references(ExploreDecks, #id, onDelete: KeyAction.cascade)();

  /// Card display name (e.g. 'The Ur-Dragon', 'Sol Ring')
  TextColumn get cardName => text().named('card_name')();

  /// Scryfall Card UUID
  TextColumn get scryfallId => text().named('scryfall_id').nullable()();

  /// Scryfall Oracle UUID
  TextColumn get oracleId => text().named('oracle_id').nullable()();

  /// Quantity in deck
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// Board zone: 'Commander' | 'Mainboard' | 'Sideboard' | 'Maybeboard'
  TextColumn get boardZone =>
      text().named('board_zone').withDefault(const Constant('Mainboard'))();

  /// Mana cost string (e.g. '{4}{W}{U}{B}{R}{G}')
  TextColumn get manaCost => text().named('mana_cost').nullable()();

  /// Converted mana cost (mana value)
  RealColumn get cmc => real().nullable()();

  /// Card type line (e.g. 'Legendary Creature — Dragon Avatar')
  TextColumn get typeLine => text().named('type_line').nullable()();

  /// Colors JSON list string (e.g. '["W","U","B","R","G"]')
  TextColumn get colors => text().nullable()();

  /// Front card artwork URL
  TextColumn get imageUrl => text().named('image_url').nullable()();

  /// High-resolution art crop URL
  TextColumn get artCropUrl => text().named('art_crop_url').nullable()();

  /// Card market price (USD)
  RealColumn get price => real().nullable()();

  /// Commander card indicator
  BoolColumn get isCommander =>
      boolean().named('is_commander').withDefault(const Constant(false))();

  /// Polymorphic Scryfall dynamic data JSON payload
  TextColumn get dynamicData => text().named('dynamic_data').nullable()();

  /// Soft deletion flag
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

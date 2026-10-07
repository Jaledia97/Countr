import 'package:drift/drift.dart';

/// Drift Table representing an Explore Deck template (official WotC precon or curated community build).
///
/// Stores discovery metadata, creator attributes, Commander references, color identity,
/// aggregate valuation, voting tallies, and carousel categorization.
@DataClassName('ExploreDeck')
class ExploreDecks extends Table {
  /// Unique identifier (e.g. UUID or stable slug like 'precon-c17-draconic-domination')
  TextColumn get id => text()();

  /// Deck title
  TextColumn get name => text()();

  /// Format (e.g. 'Commander', 'Challenger', 'Standard', 'Modern', 'Starter Kit', 'Duel Decks', 'Planechase', 'Archenemy')
  TextColumn get format => text()();

  /// TCG Domain (default 'mtg')
  TextColumn get tcgDomain =>
      text().named('tcg_domain').withDefault(const Constant('mtg'))();

  /// Origin type: 'official' | 'community' | 'user_shared'
  TextColumn get sourceType =>
      text().named('source_type').withDefault(const Constant('official'))();

  /// Creator username or publisher (e.g. 'Wizards of the Coast', '@SpicyBrewMaster', '@EDH_Rec_Fanatic', '@DraftGuru')
  TextColumn get creatorName =>
      text().named('creator_name').withDefault(const Constant('Wizards of the Coast'))();

  /// Deck description, primer summary, or strategy notes
  TextColumn get description => text().nullable()();

  /// Commander card name (for Commander decks) or primary featured card
  TextColumn get commanderName => text().named('commander_name').nullable()();

  /// Front artwork image URL for commander/cover display
  TextColumn get commanderImageUrl => text().named('commander_image_url').nullable()();

  /// High-resolution art crop URL for hero display banners
  TextColumn get commanderArtCrop => text().named('commander_art_crop').nullable()();

  /// Color identity JSON array string (e.g. '["W","U","B","R","G"]')
  TextColumn get colorIdentity =>
      text().named('color_identity').withDefault(const Constant('[]'))();

  /// Total card count in the deck (typically 100 for Commander, 60 for Standard)
  IntColumn get cardCount =>
      integer().named('card_count').withDefault(const Constant(100))();

  /// Estimated aggregate market valuation (USD)
  RealColumn get estimatedPrice =>
      real().named('estimated_price').withDefault(const Constant(0.0))();

  /// Total upvote count
  IntColumn get upvotes => integer().withDefault(const Constant(0))();

  /// Total downvote count
  IntColumn get downvotes => integer().withDefault(const Constant(0))();

  /// Popularity score (upvotes minus downvotes)
  IntColumn get score => integer().withDefault(const Constant(0))();

  /// Featured carousel category: 'Suggested Commanders' | 'From Top Deck Builders' | 'Popular Standard Decks'
  TextColumn get featuredCategory => text().named('featured_category').nullable()();

  /// Set code or product release code (e.g. 'C17', 'E01')
  TextColumn get releaseCode => text().named('release_code').nullable()();

  /// Release year (e.g. 2017)
  IntColumn get releaseYear => integer().named('release_year').nullable()();

  /// Comma-separated search tags or keywords
  TextColumn get tags => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Last modification timestamp
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

  /// Soft deletion flag for offline-first retention
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

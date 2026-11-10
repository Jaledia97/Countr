import 'package:drift/drift.dart';
import 'vault_binders_table.dart';

/// The Comprehensive Ledger Schema (VaultItems)
/// Acts as an "end-all-be-all" financial portfolio ledger for
/// Trading Cards, Comic Books, and Sports Cards with a Polymorphic JSON Engine.
class VaultItems extends Table {
  // Core Identity
  TextColumn get id => text()();
  TextColumn get collectionType => text().named('collection_type')();
  TextColumn get name => text()();
  TextColumn get setOrSeries => text().named('set_or_series')();
  TextColumn get imageUrl => text().named('image_url')();
  TextColumn get flavorName => text().named('flavor_name').nullable()();

  // Personal Inventory & Financials
  RealColumn get acquiredPrice => real().named('acquired_price')();
  DateTimeColumn get acquiredDate => dateTime().named('acquired_date')();
  IntColumn get quantity =>
      integer().named('quantity').withDefault(const Constant(1))();
  TextColumn get condition => text()();
  BoolColumn get isGraded =>
      boolean().named('is_graded').withDefault(const Constant(false))();
  BoolColumn get isAltered =>
      boolean().named('is_altered').clientDefault(() => false)();
  BoolColumn get isMisprint =>
      boolean().named('is_misprint').clientDefault(() => false)();
  BoolColumn get isSigned =>
      boolean().named('is_signed').clientDefault(() => false)();
  TextColumn get personalNotes => text().named('personal_notes').nullable()();

  // Physical Inventory & Extended Provenance (v8)
  DateTimeColumn get dateObtained =>
      dateTime().named('date_obtained').nullable()();
  RealColumn get purchasePrice =>
      real().named('purchase_price').nullable()();
  IntColumn get binderPage =>
      integer().named('binder_page').nullable()();
  TextColumn get binderSlot =>
      text().named('binder_slot').nullable()();
  TextColumn get notes =>
      text().named('notes').nullable()();
  TextColumn get protectionStatus => text()
      .named('protection_status')
      .withDefault(const Constant('Sleeved'))
      .nullable()();

  // Physical Home Anchor (NULL = unassigned / Inbox)
  TextColumn get primaryBinderId => text()
      .named('primary_binder_id')
      .nullable()
      .references(VaultBinders, #id)();

  // Live Market Engine
  RealColumn get currentMarketPrice => real().named('current_market_price')();
  DateTimeColumn get lastPriceUpdate => dateTime().named('last_price_update')();

  // The Polymorphic Engine (Stringified JSON payload for item-specific attributes)
  TextColumn get dynamicData => text().named('dynamic_data')();

  // User Scoping & Trade Engine (v12 / Epic 3)
  TextColumn get userId => text().named('user_id').nullable()();
  BoolColumn get isTraded =>
      boolean().named('is_traded').withDefault(const Constant(false)).nullable()();

  // Soft Delete & Outbox Sync (v9 & v12 / Epic 5)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();
  DateTimeColumn get deletedAt =>
      dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced')).nullable()();

  // Community Card Reputation (v14 / Milestone 4)
  IntColumn get reputationScore =>
      integer().named('reputation_score').nullable().withDefault(const Constant(0))();
  IntColumn get upvotes =>
      integer().named('upvotes').nullable().withDefault(const Constant(0))();
  IntColumn get downvotes =>
      integer().named('downvotes').nullable().withDefault(const Constant(0))();

  // Wishlist Feature (v16 / Milestone 1)
  BoolColumn get isWishlisted =>
      boolean().named('is_wishlisted').withDefault(const Constant(false)).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

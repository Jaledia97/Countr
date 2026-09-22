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

  @override
  Set<Column> get primaryKey => {id};
}
